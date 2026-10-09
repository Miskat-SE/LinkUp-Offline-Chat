import 'dart:async';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/domain/message_repository.dart';
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
final class MessagingService {
  MessagingService({
    required this._links,
    required this._repository,
    required this._self,
    required this._logger,
    this.ackTimeout = const Duration(seconds: 10),
    this.maxAttempts = 5,
  });

  final PeerLinks _links;
  final MessageRepository _repository;
  final SelfInfo Function() _self;
  final AppLogger _logger;
  final Duration ackTimeout;
  final int maxAttempts;

  static const _uuid = Uuid();

  final StreamController<ChatMessage> _incoming =
      StreamController<ChatMessage>.broadcast();
  final Map<String, Timer> _ackTimers = {};
  StreamSubscription<PeerPacket>? _packets;
  StreamSubscription<LinksSnapshot>? _linkChanges;
  Set<String> _connected = {};
  Future<void> _queue = Future.value();

  /// Newly received messages (after they are stored), for notifications.
  Stream<ChatMessage> get incoming => _incoming.stream;

  bool isConnected(String peerId) => _links.current.links.containsKey(peerId);

  void start() {
    _connected = _links.current.links.keys.toSet();
    _packets ??= _links.packets.listen((p) => _serial(() => _onPacket(p)));
    _linkChanges ??= _links.snapshots.listen((s) => _serial(() => _onLinks(s)));
  }

  Future<void> stop() async {
    unawaited(_packets?.cancel());
    unawaited(_linkChanges?.cancel());
    _packets = null;
    _linkChanges = null;
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

  /// Sends a Failed message again.
  Future<void> retry(String messageId) => _serial(() async {
    final message = await _repository.find(messageId);
    if (message == null || message.status != MessageStatus.failed) return;
    _logger.info(LogTag.message, 'Retry', {'message': _short(messageId)});
    await _transmit(message.copyWith(attempts: 0));
  });

  /// The user opened the chat: marks its messages read and tells the
  /// sender. (Receipts for a disconnected sender are queued from P5.)
  Future<void> markConversationRead(String peerId) => _serial(() async {
    final ids = await _repository.markRead(peerId);
    if (ids.isEmpty || !isConnected(peerId)) return;
    for (var i = 0; i < ids.length; i += 100) {
      _links.send(
        peerId,
        MessageReadPacket(
          _header(peerId),
          messageIds: ids.sublist(i, (i + 100).clamp(0, ids.length)),
        ),
      );
    }
  });

  /// Deletes on this phone only.
  Future<void> delete(String messageId) async {
    _ackTimers.remove(messageId)?.cancel();
    await _repository.delete(messageId);
  }

  // ----------------------------------------------------------------- sending

  Future<void> _transmit(ChatMessage message) async {
    if (!isConnected(message.peerId)) {
      await _repository.updateStatus(message.id, MessageStatus.pending);
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
        kind: MessageKind.text,
        audience: MessageAudience.direct,
        text: message.text,
        replyToId: message.replyToId,
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

  Future<void> _ackTimedOut(String messageId) async {
    _ackTimers.remove(messageId);
    final message = await _repository.find(messageId);
    if (message == null || message.status != MessageStatus.sending) return;
    if (!isConnected(message.peerId)) {
      await _repository.updateStatus(messageId, MessageStatus.pending);
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
      // Unconfirmed messages wait for the person to come back.
      for (final message in await _repository.pendingFor(peerId)) {
        _ackTimers.remove(message.id)?.cancel();
        await _repository.updateStatus(message.id, MessageStatus.pending);
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
    if (packet.kind != MessageKind.text || packet.text == null) {
      // File messages arrive with file sharing (P6).
      return;
    }
    final message = ChatMessage(
      id: header.messageId,
      peerId: from,
      peerName: header.senderName,
      direction: MessageDirection.incoming,
      text: packet.text!,
      sentAt: header.timestamp,
      createdAt: clock.now(),
      status: MessageStatus.received,
      replyToId: packet.replyToId,
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
      _links.send(
        from,
        MessageDeliveredPacket(_header(from), messageIds: [message.id]),
      );
      if (stored?.isRead ?? false) {
        _links.send(
          from,
          MessageReadPacket(_header(from), messageIds: [message.id]),
        );
      }
      return;
    }
    _logger.info(LogTag.message, 'Received', {'message': _short(message.id)});
    if (!_incoming.isClosed) _incoming.add(message);
    // While the app runs, a new message is shown at once: in the open chat,
    // the chat list, or a notification.
    _links.send(
      from,
      MessageDeliveredPacket(_header(from), messageIds: [message.id]),
    );
  }

  /// Applies a receipt from [from] to its own messages only.
  Future<void> _advance(
    String from,
    List<String> ids,
    MessageStatus status,
  ) async {
    for (final id in ids) {
      final message = await _repository.find(id);
      if (message == null || message.peerId != from || !message.isOutgoing) {
        continue;
      }
      await _repository.updateStatus(id, status);
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
