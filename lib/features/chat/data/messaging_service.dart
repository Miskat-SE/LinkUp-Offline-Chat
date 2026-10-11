import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/file_name_sanitizer.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/domain/message_repository.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:uuid/uuid.dart';

/// One-to-one text messaging over the control connections (PROTOCOL.md
/// §4.3, PROJECT_PLAN.md §7.4).
///
/// - Sending: stored first, sent if the person is connected, otherwise
///   Pending until they connect. No MESSAGE_ACK within [ackTimeout] means
///   resend with the same ID; after [maxAttempts] it is Failed.
/// - Receiving: validated, stored once (resends are ACKed again but not
///   stored twice), ACKed, then reported on [incoming] and confirmed with
///   MESSAGE_DELIVERED.
/// - Receipts move messages forward only: Sent → Delivered → Read.
/// - Outbox (§7.4): runs at start, whenever someone connects (which
///   includes after a network change), and on retry. Receipts that
///   couldn't be sent wait in the database and go out on reconnect too.
/// - Files (§7.5): a file MESSAGE goes out once the file is prepared; its
///   confirmation lets the data follow. The bytes are [TransferService]'s
///   job.
/// - Everyone (§7.4): one message to the people online at that moment,
///   tracked per recipient with the same retries and receipts as a direct
///   message. Selected people get one direct message each.
final class MessagingService {
  MessagingService({
    required this._links,
    required this._repository,
    required this._self,
    required this._logger,
    this._transfers,
    this.ackTimeout = const Duration(seconds: 10),
    this.maxAttempts = 5,
  });

  final PeerLinks _links;
  final MessageRepository _repository;
  final SelfInfo Function() _self;
  final AppLogger _logger;
  final TransferService? _transfers;
  final Duration ackTimeout;
  final int maxAttempts;

  static const _uuid = Uuid();

  /// Message IDs per receipt packet; well under the 64 KiB frame limit.
  static const _receiptBatch = 100;

  final StreamController<ChatMessage> _incoming =
      StreamController<ChatMessage>.broadcast();
  final Map<String, Timer> _ackTimers = {};
  StreamSubscription<PeerPacket>? _packets;
  StreamSubscription<LinksSnapshot>? _linkChanges;
  StreamSubscription<String>? _filesReady;
  Set<String> _connected = {};
  Future<void> _queue = Future.value();

  /// Newly received messages (after they are stored), for notifications.
  Stream<ChatMessage> get incoming => _incoming.stream;

  bool isConnected(String peerId) => _links.current.links.containsKey(peerId);

  void start() {
    if (_packets != null) return;
    _packets = _links.packets.listen((p) => _serial(() => _onPacket(p)));
    _linkChanges = _links.snapshots.listen((s) => _serial(() => _onLinks(s)));
    _filesReady = _transfers?.ready.listen(
      (fileId) => _serial(() => _fileReady(fileId)),
    );
    unawaited(_serial(_recover));
  }

  /// At app start nothing is in flight: interrupted sends wait again, and
  /// anyone already connected gets their queued messages and receipts.
  Future<void> _recover() async {
    final interrupted = await _repository.resetInterrupted();
    if (interrupted > 0) {
      _logger.info(LogTag.message, 'Interrupted sends queued again', {
        'count': interrupted,
      });
    }
    await _onLinks(_links.current);
  }

  Future<void> stop() async {
    unawaited(_packets?.cancel());
    unawaited(_linkChanges?.cancel());
    unawaited(_filesReady?.cancel());
    _packets = null;
    _linkChanges = null;
    _filesReady = null;
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    await _incoming.close();
  }

  /// Sends [text] to [peerId]. The message is stored at once and shown as
  /// Sending, or Pending if they are offline.
  Future<ChatMessage> sendText({
    required String peerId,
    required String peerName,
    required String text,
    String? replyToId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'is empty');
    }
    final now = clock.now();
    final message = ChatMessage(
      id: _uuid.v4(),
      peerId: peerId,
      peerName: peerName,
      direction: MessageDirection.outgoing,
      text: trimmed,
      sentAt: now,
      createdAt: now,
      status: MessageStatus.pending,
      replyToId: replyToId,
    );
    await _repository.insertOutgoing(message);
    await _serial(() => _transmit(message));
    return await _repository.find(message.id) ?? message;
  }

  /// Sends files to [peerId], one message each. Each appears at once as
  /// Preparing, and goes out when it is copied and hashed.
  Future<List<ChatMessage>> sendFiles({
    required String peerId,
    required String peerName,
    required List<PickedFile> files,
  }) => _serial(() async {
    final transfers = _transfers;
    if (transfers == null) throw StateError('file sharing is not set up');
    final sent = <ChatMessage>[];
    for (final picked in files) {
      final now = clock.now();
      final messageId = _uuid.v4();
      final fileId = _uuid.v4();
      final transfer = await transfers.prepareOutgoing(
        picked,
        fileId: fileId,
        messageId: messageId,
        peerId: peerId,
      );
      final message = ChatMessage(
        id: messageId,
        peerId: peerId,
        peerName: peerName,
        direction: MessageDirection.outgoing,
        text: '',
        sentAt: now,
        createdAt: now,
        status: MessageStatus.pending,
        content: MessageContent.file,
        fileId: fileId,
        fileName: transfer.name,
      );
      await _repository.insertOutgoing(message);
      sent.add(message);
    }
    return sent;
  });

  /// Sends the same text and files to each of [people] as their own direct
  /// message (multi-select, P7.3); those offline get them when they're
  /// back. Each file is copied and hashed once.
  /// Sends [message] again (P15.3) to [people], to everyone online, or
  /// both. A file goes from this phone's copy; returns false if the file
  /// isn't on this phone (still arriving, or deleted).
  Future<bool> forward(
    ChatMessage message, {
    Map<String, String> people = const {},
    bool everyone = false,
    Map<String, String> names = const {},
  }) async {
    final transfers = _transfers;
    final copies = <PickedFile>[];
    Future<List<PickedFile>> files() async {
      if (!message.isFile) return const [];
      final copy = await transfers?.copyForSending(message.fileId!);
      if (copy == null) return const [];
      copies.add(copy);
      return [copy];
    }

    final text = message.isFile ? null : message.text;
    try {
      if (people.isNotEmpty) {
        final picked = await files();
        if (message.isFile && picked.isEmpty) return false;
        await sendToPeople(people: people, text: text, files: picked);
      }
      if (everyone) {
        final picked = await files();
        if (message.isFile && picked.isEmpty) return false;
        await sendToEveryone(text: text, files: picked, names: names);
      }
      _logger.info(LogTag.message, 'Forwarded', {
        'people': people.length,
        'everyone': everyone,
      });
      return true;
    } finally {
      // Sending moved the copies into sent/; drop their folders.
      for (final copy in copies) {
        try {
          await File(copy.path).parent.delete(recursive: true);
        } on FileSystemException {
          // Already gone.
        }
      }
    }
  }

  Future<void> sendToPeople({
    required Map<String, String> people,
    String? text,
    List<PickedFile> files = const [],
  }) async {
    final trimmed = text?.trim() ?? '';
    if (people.isEmpty || (trimmed.isEmpty && files.isEmpty)) {
      throw ArgumentError('nothing to send');
    }
    if (trimmed.isNotEmpty) {
      for (final MapEntry(key: id, value: name) in people.entries) {
        await sendText(peerId: id, peerName: name, text: trimmed);
      }
    }
    if (files.isEmpty) return;
    await _serial(() async {
      for (final picked in files) {
        String? source;
        for (final MapEntry(key: id, value: name) in people.entries) {
          source = await _queueFile(picked, id, name, sharing: source);
        }
      }
    });
  }

  /// Stores a file message to [peerId]; the first copy of a file moves and
  /// hashes it, later ones share it. Returns the new file ID.
  Future<String> _queueFile(
    PickedFile picked,
    String peerId,
    String peerName, {
    String? sharing,
  }) async {
    final transfers = _transfers!;
    final now = clock.now();
    final messageId = _uuid.v4();
    final fileId = _uuid.v4();
    final transfer = sharing == null
        ? await transfers.prepareOutgoing(
            picked,
            fileId: fileId,
            messageId: messageId,
            peerId: peerId,
          )
        : await transfers.shareOutgoing(
            sharing,
            fileId: fileId,
            messageId: messageId,
            peerId: peerId,
          );
    await _repository.insertOutgoing(
      ChatMessage(
        id: messageId,
        peerId: peerId,
        peerName: peerName,
        direction: MessageDirection.outgoing,
        text: '',
        sentAt: now,
        createdAt: now,
        status: MessageStatus.pending,
        content: MessageContent.file,
        fileId: fileId,
        fileName: transfer.name,
      ),
    );
    // Already hashed (a shared copy): send now if they are connected.
    if (transfer.sha256 != null) await _fileReady(fileId);
    return fileId;
  }

  /// Sends to everyone online right now (P7.2). Returns the messages, or
  /// an empty list if nobody is online. [names] supplies display names;
  /// the connection's name is used otherwise.
  Future<List<ChatMessage>> sendToEveryone({
    String? text,
    List<PickedFile> files = const [],
    Map<String, String> names = const {},
    String? replyToId,
  }) => _serial(() async {
    final online = {
      for (final link in _links.current.links.values)
        link.peerId:
            names[link.peerId] ??
            (link.peerName.isEmpty ? 'Someone' : link.peerName),
    };
    if (online.isEmpty) return const <ChatMessage>[];
    final trimmed = text?.trim() ?? '';
    final sent = <ChatMessage>[];
    if (trimmed.isNotEmpty) {
      sent.add(await _broadcast(online, text: trimmed, replyToId: replyToId));
    }
    for (final picked in files) {
      sent.add(await _broadcast(online, file: picked));
    }
    _logger.info(LogTag.message, 'Sent to everyone', {
      'people': online.length,
      'messages': sent.length,
    });
    return sent;
  });

  Future<ChatMessage> _broadcast(
    Map<String, String> online, {
    String text = '',
    PickedFile? file,
    String? replyToId,
  }) async {
    final now = clock.now();
    final messageId = _uuid.v4();
    final fileIds = <String, String>{};
    String? fileName;
    if (file != null) {
      String? source;
      for (final peerId in online.keys) {
        final fileId = _uuid.v4();
        final transfer = source == null
            ? await _transfers!.prepareOutgoing(
                file,
                fileId: fileId,
                messageId: messageId,
                peerId: peerId,
              )
            : await _transfers!.shareOutgoing(
                source,
                fileId: fileId,
                messageId: messageId,
                peerId: peerId,
              );
        source ??= fileId;
        fileName = transfer.name;
        fileIds[peerId] = fileId;
      }
    }
    final message = ChatMessage(
      id: messageId,
      peerId: ChatMessage.everyone,
      peerName: 'Everyone',
      direction: MessageDirection.outgoing,
      text: text,
      sentAt: now,
      createdAt: now,
      status: MessageStatus.sent,
      content: file == null ? MessageContent.text : MessageContent.file,
      fileId: fileIds.values.firstOrNull,
      fileName: fileName,
      audience: ChatAudience.everyone,
      replyToId: replyToId,
    );
    final recipients = [
      for (final MapEntry(key: id, value: name) in online.entries)
        MessageRecipient(
          messageId: messageId,
          recipientId: id,
          recipientName: name,
          status: MessageStatus.pending,
          fileId: fileIds[id],
        ),
    ];
    await _repository.insertBroadcast(message, recipients);
    for (final recipient in recipients) {
      await _transmitTo(message, recipient);
    }
    return message;
  }

  /// A file finished preparing: its message can go out.
  Future<void> _fileReady(String fileId) async {
    final transfer = await _transfers?.find(fileId);
    if (transfer == null) return;
    final message = await _repository.find(transfer.messageId);
    if (message == null) return;
    if (message.isBroadcast) {
      for (final r in await _repository.recipients(message.id)) {
        if (r.fileId == fileId && r.status == MessageStatus.pending) {
          await _transmitTo(message, r);
        }
      }
      return;
    }
    if (message.status != MessageStatus.pending) return;
    await _transmit(message);
  }

  /// Sends a Failed message again; for Everyone, to those it failed for.
  Future<void> retry(String messageId) => _serial(() async {
    final message = await _repository.find(messageId);
    if (message == null) return;
    if (message.isBroadcast) {
      for (final r in await _repository.recipients(messageId)) {
        if (r.status == MessageStatus.failed) {
          await _transmitTo(message, r.copyWith(attempts: 0));
        }
      }
      return;
    }
    if (message.status != MessageStatus.failed) return;
    _logger.info(LogTag.message, 'Retry', {'message': _short(messageId)});
    await _transmit(message.copyWith(attempts: 0));
  });

  /// The user opened the chat: marks its messages read and tells the
  /// sender, now or when they reconnect.
  Future<void> markConversationRead(String conversationId) => _serial(() async {
    final bySender = await _repository.markRead(conversationId);
    for (final MapEntry(key: sender, value: ids) in bySender.entries) {
      await _sendReceipts(sender, ids, Receipt.read);
    }
  });

  /// Deletes on this phone only, with its file if it has one.
  Future<void> delete(String messageId) async {
    _ackTimers.remove(messageId)?.cancel();
    final message = await _repository.find(messageId);
    final recipients = await _repository.recipients(messageId);
    for (final r in recipients) {
      _ackTimers.remove(_key(messageId, r.recipientId))?.cancel();
    }
    await _repository.delete(messageId);
    final fileIds = {?message?.fileId, for (final r in recipients) ?r.fileId};
    for (final fileId in fileIds) {
      await _transfers?.discard(fileId);
    }
  }

  // ----------------------------------------------------------------- sending

  Future<void> _transmit(ChatMessage message) async {
    // A file message waits until its file is prepared.
    final fileId = message.fileId;
    final file = fileId == null ? null : await _transfers?.fileRef(fileId);
    if (!isConnected(message.peerId) || (message.isFile && file == null)) {
      await _repository.updateStatus(
        message.id,
        MessageStatus.pending,
        attempts: 0,
      );
      return;
    }
    final attempts = message.attempts + 1;
    await _repository.updateStatus(
      message.id,
      MessageStatus.sending,
      attempts: attempts,
    );
    final self = _self();
    _links.send(
      message.peerId,
      MessagePacket(
        PacketHeader(
          messageId: message.id,
          senderId: self.deviceId,
          senderName: self.name ?? '',
          receiverId: message.peerId,
          timestamp: PacketHeader.wireTime(message.sentAt),
        ),
        kind: message.isFile ? MessageKind.file : MessageKind.text,
        audience: MessageAudience.direct,
        text: message.isFile ? null : message.text,
        replyToId: message.replyToId,
        file: file,
      ),
    );
    _logger.info(LogTag.message, 'Sent', {
      'message': _short(message.id),
      'attempt': attempts,
    });
    _ackTimers.remove(message.id)?.cancel();
    _ackTimers[message.id] = Timer(
      ackTimeout,
      () => unawaited(_serial(() => _ackTimedOut(message.id))),
    );
  }

  /// Sends an Everyone message to one recipient, with its own retries.
  Future<void> _transmitTo(ChatMessage message, MessageRecipient r) async {
    final peerId = r.recipientId;
    final fileId = r.fileId;
    final file = fileId == null ? null : await _transfers?.fileRef(fileId);
    if (!isConnected(peerId) || (message.isFile && file == null)) {
      await _repository.updateRecipient(
        message.id,
        peerId,
        MessageStatus.pending,
        attempts: 0,
      );
      return;
    }
    final attempts = r.attempts + 1;
    await _repository.updateRecipient(
      message.id,
      peerId,
      MessageStatus.sending,
      attempts: attempts,
    );
    final self = _self();
    _links.send(
      peerId,
      MessagePacket(
        PacketHeader(
          messageId: message.id,
          senderId: self.deviceId,
          senderName: self.name ?? '',
          receiverId: peerId,
          timestamp: PacketHeader.wireTime(message.sentAt),
        ),
        kind: message.isFile ? MessageKind.file : MessageKind.text,
        audience: MessageAudience.broadcast,
        text: message.isFile ? null : message.text,
        replyToId: message.replyToId,
        file: file,
      ),
    );
    final key = _key(message.id, peerId);
    _ackTimers.remove(key)?.cancel();
    _ackTimers[key] = Timer(
      ackTimeout,
      () => unawaited(_serial(() => _deliveryTimedOut(message.id, peerId))),
    );
  }

  Future<void> _deliveryTimedOut(String messageId, String peerId) async {
    _ackTimers.remove(_key(messageId, peerId));
    final message = await _repository.find(messageId);
    if (message == null) return;
    MessageRecipient? recipient;
    for (final r in await _repository.recipients(messageId)) {
      if (r.recipientId == peerId) recipient = r;
    }
    if (recipient == null || recipient.status != MessageStatus.sending) return;
    if (!isConnected(peerId)) {
      await _repository.updateRecipient(
        messageId,
        peerId,
        MessageStatus.pending,
        attempts: 0,
      );
    } else if (recipient.attempts >= maxAttempts) {
      await _repository.updateRecipient(
        messageId,
        peerId,
        MessageStatus.failed,
      );
    } else {
      await _transmitTo(message, recipient);
    }
  }

  static String _key(String messageId, String peerId) => '$messageId|$peerId';

  Future<void> _ackTimedOut(String messageId) async {
    _ackTimers.remove(messageId);
    final message = await _repository.find(messageId);
    if (message == null || message.status != MessageStatus.sending) return;
    if (!isConnected(message.peerId)) {
      await _repository.updateStatus(
        messageId,
        MessageStatus.pending,
        attempts: 0,
      );
    } else if (message.attempts >= maxAttempts) {
      _logger.warning(LogTag.message, 'Not confirmed, giving up', {
        'message': _short(messageId),
      });
      await _repository.updateStatus(messageId, MessageStatus.failed);
    } else {
      await _transmit(message);
    }
  }

  Future<void> _onLinks(LinksSnapshot snapshot) async {
    final now = snapshot.links.keys.toSet();
    final joined = now.difference(_connected);
    final left = _connected.difference(now);
    _connected = now;
    for (final peerId in left) {
      // Unconfirmed messages wait for the person to come back, and get a
      // full set of attempts on the next connection.
      for (final message in await _repository.pendingFor(peerId)) {
        _ackTimers.remove(message.id)?.cancel();
        await _repository.updateStatus(
          message.id,
          MessageStatus.pending,
          attempts: 0,
        );
      }
      for (final (message, _) in await _repository.pendingDeliveriesTo(
        peerId,
      )) {
        _ackTimers.remove(_key(message.id, peerId))?.cancel();
        await _repository.updateRecipient(
          message.id,
          peerId,
          MessageStatus.pending,
          attempts: 0,
        );
      }
    }
    for (final peerId in joined) {
      final waiting = await _repository.pendingFor(peerId);
      if (waiting.isNotEmpty) {
        _logger.info(LogTag.message, 'Sending queued messages', {
          'device': _short(peerId),
          'count': waiting.length,
        });
      }
      for (final message in waiting) {
        await _transmit(message);
      }
      for (final (message, r) in await _repository.pendingDeliveriesTo(
        peerId,
      )) {
        await _transmitTo(message, r);
      }
      for (final receipt in [Receipt.delivered, Receipt.read]) {
        final owed = await _repository.owedReceipts(peerId, receipt);
        if (owed.isNotEmpty) await _sendReceipts(peerId, owed, receipt);
      }
    }
  }

  // --------------------------------------------------------------- receiving

  Future<void> _onPacket(PeerPacket incoming) async {
    final from = incoming.from;
    switch (incoming.packet) {
      case final MessagePacket packet:
        await _onMessage(from, packet);
      case MessageAckPacket(:final ackFor):
        _ackTimers.remove(ackFor)?.cancel();
        await _advance(from, [ackFor], MessageStatus.sent);
      case MessageDeliveredPacket(:final messageIds):
        for (final id in messageIds) {
          _ackTimers.remove(id)?.cancel();
        }
        await _advance(from, messageIds, MessageStatus.delivered);
      case MessageReadPacket(:final messageIds):
        for (final id in messageIds) {
          _ackTimers.remove(id)?.cancel();
        }
        await _advance(from, messageIds, MessageStatus.read);
      default:
        break;
    }
  }

  Future<void> _onMessage(String from, MessagePacket packet) async {
    final header = packet.header;
    final self = _self();
    if (header.receiverId != self.deviceId) {
      _logger.warning(LogTag.message, 'Message for someone else ignored', {
        'from': _short(from),
      });
      return;
    }
    final file = packet.file;
    if (packet.kind == MessageKind.file) {
      final transfers = _transfers;
      if (file == null || transfers == null) return;
      // Recorded before the ACK, so the file's data is expected.
      final accepted = await transfers.registerIncoming(
        file,
        peerId: from,
        messageId: header.messageId,
      );
      if (!accepted) {
        _logger.warning(LogTag.message, 'File message with a used ID', {
          'from': _short(from),
        });
        return;
      }
    } else if (packet.text == null) {
      return;
    }
    // Everyone messages go to the Everyone thread, with the sender's name.
    final everyone = packet.audience == MessageAudience.broadcast;
    final message = ChatMessage(
      id: header.messageId,
      peerId: everyone ? ChatMessage.everyone : from,
      peerName: header.senderName,
      audience: everyone ? ChatAudience.everyone : ChatAudience.direct,
      senderId: everyone ? from : null,
      direction: MessageDirection.incoming,
      text: file == null ? packet.text! : '',
      sentAt: header.timestamp,
      createdAt: clock.now(),
      status: MessageStatus.received,
      replyToId: packet.replyToId,
      content: file == null ? MessageContent.text : MessageContent.file,
      fileId: file?.fileId,
      fileName: file == null ? null : FileNameSanitizer.sanitize(file.name),
    );
    final isNew = await _repository.insertIncoming(message);
    // Always confirm, so a resend after a lost ACK stops.
    _links.send(
      from,
      MessageAckPacket(_header(from), ackFor: header.messageId),
    );
    if (!isNew) {
      // A resend: the earlier receipts may have been lost too, so repeat
      // them (receipts are safe to repeat).
      _logger.debug(LogTag.message, 'Duplicate, receipts repeated', {
        'message': _short(message.id),
      });
      final stored = await _repository.find(message.id);
      await _sendReceipts(from, [message.id], Receipt.delivered);
      if (stored?.isRead ?? false) {
        await _sendReceipts(from, [message.id], Receipt.read);
      }
      return;
    }
    _logger.info(LogTag.message, 'Received', {'message': _short(message.id)});
    if (!_incoming.isClosed) _incoming.add(message);
    // While the app runs, a new message is shown at once: in the open chat,
    // the chat list, or a notification.
    await _sendReceipts(from, [message.id], Receipt.delivered);
  }

  /// Sends [receipt] for [ids] to [peerId] in batches and records what was
  /// handed to the connection; the rest waits for the next connection.
  Future<void> _sendReceipts(
    String peerId,
    List<String> ids,
    Receipt receipt,
  ) async {
    if (!isConnected(peerId)) return;
    for (var i = 0; i < ids.length; i += _receiptBatch) {
      final batch = ids.sublist(i, (i + _receiptBatch).clamp(0, ids.length));
      final header = _header(peerId);
      final sent = _links.send(
        peerId,
        receipt == Receipt.read
            ? MessageReadPacket(header, messageIds: batch)
            : MessageDeliveredPacket(header, messageIds: batch),
      );
      if (!sent) return;
      await _repository.recordReceipts(batch, receipt);
    }
  }

  /// Applies a receipt from [from] to its own messages only.
  Future<void> _advance(
    String from,
    List<String> ids,
    MessageStatus status,
  ) async {
    for (final id in ids) {
      final message = await _repository.find(id);
      if (message == null || !message.isOutgoing) continue;
      if (message.isBroadcast) {
        _ackTimers.remove(_key(id, from))?.cancel();
        final recipient = await _repository.updateRecipient(id, from, status);
        final fileId = recipient?.fileId;
        if (fileId != null) await _transfers?.onFileMessageAccepted(fileId);
        continue;
      }
      if (message.peerId != from) continue;
      await _repository.updateStatus(id, status);
      // Any receipt means the file message was stored: send the data.
      final fileId = message.fileId;
      if (fileId != null) await _transfers?.onFileMessageAccepted(fileId);
    }
  }

  PacketHeader _header(String receiverId) {
    final self = _self();
    return PacketHeader.create(
      senderId: self.deviceId,
      senderName: self.name ?? '',
      receiverId: receiverId,
    );
  }

  static String _short(String id) => id.substring(0, 4);

  /// Runs message work one step at a time, in arrival order.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then(
      (_) {},
      onError: (Object e) {
        _logger.error(LogTag.message, 'Messaging step failed', {
          'error': e.runtimeType,
        });
      },
    );
    return result;
  }
}
