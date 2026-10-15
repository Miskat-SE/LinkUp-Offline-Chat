import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:resqmesh/core/network/connection/byte_link.dart';
import 'package:resqmesh/core/network/inbound_limits.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/file_transfer/data/engine/data_connection.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';

/// Timings for data connections. Tests shorten them.
final class TransferTiming {
  const TransferTiming({
    this.connectTimeout = const Duration(seconds: 5),
    this.helloTimeout = const Duration(seconds: 5),
    this.offerTimeout = const Duration(seconds: 10),
    this.answerTimeout = const Duration(minutes: 2),
    this.idleTimeout = const Duration(minutes: 2),
    this.progressInterval = const Duration(milliseconds: 100),
  });

  /// Bluetooth (P14): channels take longer to open.
  static const bluetooth = TransferTiming(
    connectTimeout: Duration(seconds: 20),
    helloTimeout: Duration(seconds: 15),
    progressInterval: Duration(milliseconds: 300),
  );

  final Duration connectTimeout;
  final Duration helloTimeout;

  /// The sender must offer a file this soon after HELLO.
  final Duration offerTimeout;

  /// Longest wait for FILE_ACCEPT (the receiver may re-hash a large partial
  /// file first) and for FILE_COMPLETE after the last byte.
  final Duration answerTimeout;
  final Duration idleTimeout;

  /// At most one progress event per transfer per interval.
  final Duration progressInterval;
}

/// Moves file bytes over data connections (PROTOCOL.md §4.4). Pure
/// `dart:io`, so it runs in the transfer isolate (ADR-0010) and in tests.
///
/// - Sending reads [chunkSize] bytes at a time and waits for the socket
///   every [flushEvery] bytes: memory stays flat whatever the file size.
/// - Receiving appends to a `.part` file, hashing as bytes arrive. On
///   resume the partial file is hashed again first. The file is synced and
///   renamed into place only after the SHA-256 matches.
final class TransferEngine implements TransferBackend {
  TransferEngine({
    this.preferredPort = 28762,
    this.timing = const TransferTiming(),
    this.chunkSize = 64 * 1024,
    this.flushEvery = 1024 * 1024,
    InternetAddress? bindAddress,
    LinkTransport? transport,
    this.maxDownloads = 8,
    this.maxPending = 8,
  }) : _transport =
           transport ??
           TcpTransport(preferredPort: preferredPort, bindAddress: bindAddress);

  final int preferredPort;
  final TransferTiming timing;
  final int chunkSize;
  final int flushEvery;
  final int maxDownloads;

  /// Data connections still in HELLO or waiting for their offer (P9.3).
  final int maxPending;
  int _pending = 0;
  final RateLimiter _accepts = RateLimiter(
    limit: 30,
    window: const Duration(minutes: 1),
  );

  /// TCP on Wi-Fi; Bluetooth channels in Bluetooth mode (P14).
  final LinkTransport _transport;

  TransferIdentity? _self;

  /// The file port (or Bluetooth channel) while listening.
  int? _port;
  final Map<String, _Upload> _uploads = {};
  final Map<String, _Download> _downloads = {};
  final StreamController<TransferEvent> _events =
      StreamController<TransferEvent>.broadcast();

  @override
  Stream<TransferEvent> get events => _events.stream;

  @override
  Future<int?> start(TransferIdentity self) async {
    _self = self;
    if (_port != null) return _port;
    return _listen();
  }

  @override
  Future<int?> reset() async {
    await _closeServer();
    for (final upload in _uploads.values.toList()) {
      upload.connection?.close('network changed');
    }
    for (final download in _downloads.values.toList()) {
      download.connection.close('network changed');
    }
    return _self == null ? null : _listen();
  }

  @override
  void updateIdentity(TransferIdentity self) => _self = self;

  @override
  void upload(UploadRequest request) {
    if (_uploads.containsKey(request.fileId)) return;
    final upload = _Upload(request);
    _uploads[request.fileId] = upload;
    unawaited(_runUpload(upload));
  }

  @override
  void answer(String fileId, OfferAnswer answer) {
    final download = _downloads[fileId];
    if (download == null || download.answer.isCompleted) return;
    download.answer.complete(answer);
  }

  @override
  void stop(String fileId, FileCancelReason reason) {
    _uploads[fileId]?.stopRequested ??= reason;
    final download = _downloads[fileId];
    if (download != null) unawaited(_stopDownload(download, reason));
  }

  @override
  Future<String> hashFile(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();

  @override
  Future<void> dispose() async {
    await reset();
    await _closeServer();
    _self = null;
    await _events.close();
  }

  // ------------------------------------------------------------------ server

  Future<int?> _listen() async =>
      _port = await _transport.listen((link) => unawaited(_accept(link)));

  Future<void> _closeServer() async {
    await _transport.close();
    _port = null;
  }

  HelloPacket _hello(TransferIdentity self, {String? to}) => HelloPacket(
    PacketHeader.create(
      senderId: self.deviceId,
      senderName: self.name,
      receiverId: to ?? PacketHeader.everyone,
    ),
    Announcement(
      tcpPort: _port ?? preferredPort,
      filePort: _port,
      appVersion: self.appVersion,
      nameClaimedAt: self.nameClaimedAt,
    ),
  );

  PacketHeader _header(String to) {
    final self = _self!;
    return PacketHeader.create(
      senderId: self.deviceId,
      senderName: self.name,
      receiverId: to,
    );
  }

  void _emit(TransferEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  // ----------------------------------------------------------------- sending

  Future<void> _runUpload(_Upload upload) async {
    final request = upload.request;
    final outcome = await _send(upload);
    _uploads.remove(request.fileId);
    upload.connection?.close('done');
    await upload.file?.close().catchError((Object _) {});
    _emit(TransferEnded(request.fileId, outcome, bytes: upload.sent));
  }

  Future<TransferOutcome> _send(_Upload upload) async {
    final request = upload.request;
    final self = _self;
    if (self == null) {
      return const TransferFailed(TransferFailure.connectionLost, 'stopped');
    }
    final source = File(request.path);
    try {
      if (!source.existsSync() || await source.length() != request.fileSize) {
        return const TransferFailed(TransferFailure.unavailable);
      }
    } on FileSystemException {
      return const TransferFailed(TransferFailure.unavailable);
    }

    // DataConnection owns the socket and closes it.
    // ignore: close_sinks
    final ByteLink socket;
    try {
      socket = await _transport.connect(
        request.address,
        request.port,
        timing.connectTimeout,
      );
    } on SocketException catch (e) {
      return TransferFailed(TransferFailure.connectionLost, e.message);
    } on LinkException catch (e) {
      return TransferFailed(TransferFailure.connectionLost, e.message);
    }
    final DataConnection connection;
    try {
      connection = await DataConnection.open(
        socket: socket,
        hello: _hello(self, to: request.peerId),
        expectedPeerId: request.peerId,
        helloTimeout: timing.helloTimeout,
        idleTimeout: timing.idleTimeout,
        onFrame: upload.onFrame,
      );
    } on DataHandshakeException catch (e) {
      return TransferFailed(TransferFailure.connectionLost, e.reason);
    }
    upload.connection = connection;
    unawaited(connection.closed.then((_) => upload.wake()));

    if (upload.stopRequested case final reason?) {
      return _stopUpload(upload, reason);
    }
    connection.send(
      FileOfferPacket(
        _header(request.peerId),
        fileId: request.fileId,
        chatMessageId: request.chatMessageId,
        fileName: request.fileName,
        fileSize: request.fileSize,
        mimeType: request.mimeType,
        sha256: request.sha256,
      ),
    );

    final answer = await upload.next(timing.answerTimeout);
    if (upload.stopRequested case final reason?) {
      return _stopUpload(upload, reason);
    }
    switch (answer) {
      case null:
        return connection.isClosed
            ? const TransferFailed(TransferFailure.connectionLost)
            : const TransferFailed(TransferFailure.timedOut);
      case FileRejectPacket(:final reason):
        return TransferRejected(reason);
      case FileCompletePacket():
        upload.sent = request.fileSize;
        return const TransferCompleted();
      case FileCancelPacket(:final reason):
        return StoppedByPeer(reason);
      case FileAcceptPacket(:final offset):
        if (offset > request.fileSize) {
          return const TransferFailed(TransferFailure.protocol, 'bad offset');
        }
        return _stream(upload, offset);
      default:
        return TransferFailed(TransferFailure.protocol, answer.type);
    }
  }

  Future<TransferOutcome> _stream(_Upload upload, int offset) async {
    final request = upload.request;
    final connection = upload.connection!;
    _emit(TransferStarted(request.fileId, offset: offset));
    upload.sent = offset;
    try {
      final file = upload.file = await File(request.path).open();
      await file.setPosition(offset);
      var unflushed = 0;
      var lastProgress = clock.now();
      while (upload.sent < request.fileSize) {
        if (upload.stopRequested case final reason?) {
          return await _stopUpload(upload, reason);
        }
        if (upload.peerStop case final reason?) return StoppedByPeer(reason);
        if (connection.isClosed) {
          return const TransferFailed(TransferFailure.connectionLost);
        }
        final want = request.fileSize - upload.sent < chunkSize
            ? request.fileSize - upload.sent
            : chunkSize;
        final bytes = await file.read(want);
        if (bytes.length != want) {
          return const TransferFailed(
            TransferFailure.unavailable,
            'short read',
          );
        }
        connection.sendChunk(bytes);
        upload.sent += want;
        unflushed += want;
        if (unflushed >= flushEvery) {
          await connection.flush();
          unflushed = 0;
        }
        final now = clock.now();
        if (now.difference(lastProgress) >= timing.progressInterval) {
          lastProgress = now;
          _emit(TransferProgressed(request.fileId, bytes: upload.sent));
        }
      }
      await connection.flush();
    } on FileSystemException catch (e) {
      return TransferFailed(TransferFailure.unavailable, e.message);
    }
    _emit(TransferProgressed(request.fileId, bytes: upload.sent));

    // Wait for the receiver to verify, sync and rename.
    final Packet? last;
    if (upload.peerStop case final reason?) return StoppedByPeer(reason);
    last = await upload.next(timing.answerTimeout);
    if (upload.stopRequested case final reason?) {
      return _stopUpload(upload, reason);
    }
    return switch (last) {
      FileCompletePacket(:final sha256) when sha256 == request.sha256 =>
        const TransferCompleted(),
      FileCompletePacket() => const TransferFailed(
        TransferFailure.checksumMismatch,
      ),
      FileCancelPacket(:final reason) => StoppedByPeer(reason),
      null when connection.isClosed => const TransferFailed(
        TransferFailure.connectionLost,
      ),
      null => const TransferFailed(TransferFailure.timedOut),
      _ => TransferFailed(TransferFailure.protocol, last.type),
    };
  }

  Future<TransferOutcome> _stopUpload(
    _Upload upload,
    FileCancelReason reason,
  ) async {
    final connection = upload.connection;
    if (connection != null && !connection.isClosed) {
      connection.send(
        FileCancelPacket(
          _header(upload.request.peerId),
          fileId: upload.request.fileId,
          reason: reason,
        ),
      );
      await connection.finish('stopped');
    }
    return StoppedHere(reason);
  }

  // --------------------------------------------------------------- receiving

  Future<void> _accept(ByteLink socket) async {
    final self = _self;
    if (self == null ||
        _downloads.length >= maxDownloads ||
        _pending >= maxPending ||
        !_accepts.allow(socket.address)) {
      socket.destroy();
      return;
    }
    _pending++;
    try {
      await _receive(socket, self);
    } finally {
      _pending--;
    }
  }

  Future<void> _receive(ByteLink socket, TransferIdentity self) async {
    final offer = Completer<FileOfferPacket>();
    _Download? download;
    final DataConnection connection;
    try {
      connection = await DataConnection.open(
        socket: socket,
        hello: _hello(self),
        helloTimeout: timing.helloTimeout,
        idleTimeout: timing.idleTimeout,
        onFrame: (frame) async {
          final current = download;
          if (current != null) return _onDownloadFrame(current, frame);
          if (frame case PacketFrame(:final FileOfferPacket packet)
              when !offer.isCompleted) {
            offer.complete(packet);
          }
        },
      );
    } on DataHandshakeException {
      return;
    }

    final FileOfferPacket packet;
    try {
      packet = await offer.future.timeout(timing.offerTimeout);
    } on TimeoutException {
      connection.close('no offer');
      return;
    }
    if (packet.header.receiverId != self.deviceId) {
      connection
        ..send(
          FileRejectPacket(
            _header(connection.peerId),
            fileId: packet.fileId,
            reason: FileRejectReason.invalid,
          ),
        )
        ..close('offer for someone else');
      return;
    }
    // A sender reconnecting after a drop replaces the old connection.
    final previous = _downloads[packet.fileId];
    if (previous != null) {
      previous.connection.close('replaced');
      await previous.finished.future;
    }
    final current = download = _Download(packet, connection);
    _downloads[packet.fileId] = current;
    unawaited(
      connection.closed.then((_) {
        if (!current.finished.isCompleted) {
          unawaited(
            _endDownload(
              current,
              const TransferFailed(TransferFailure.connectionLost),
            ),
          );
        }
      }),
    );
    _emit(OfferReceived(packet, peerId: connection.peerId));

    final OfferAnswer answer;
    try {
      answer = await current.answer.future.timeout(timing.offerTimeout);
    } on TimeoutException {
      connection.close('no answer from the app');
      return;
    }
    if (current.finished.isCompleted) return;
    switch (answer) {
      case RejectOffer(:final reason):
        connection.send(
          FileRejectPacket(
            _header(connection.peerId),
            fileId: packet.fileId,
            reason: reason,
          ),
        );
        await connection.finish('rejected');
        await _endDownload(current, TransferRejected(reason));
      case AlreadyHaveFile():
        connection.send(
          FileCompletePacket(
            _header(connection.peerId),
            fileId: packet.fileId,
            sha256: packet.sha256,
          ),
        );
        await connection.finish('already complete');
        current.received = packet.fileSize;
        await _endDownload(current, const TransferCompleted());
      case AcceptOffer():
        await _startReceiving(current, answer);
    }
  }

  Future<void> _startReceiving(_Download download, AcceptOffer accept) async {
    final offer = download.offer;
    try {
      final part = File(accept.partPath);
      await part.parent.create(recursive: true);
      final file = download.file = await part.open(mode: FileMode.append);
      var offset = await file.length();
      if (offset > offer.fileSize) {
        await file.truncate(0);
        offset = 0;
      }
      // Rebuild the hash of what is already there (resume).
      download.hasher = sha256.startChunkedConversion(download.digest);
      if (offset > 0) {
        final reader = await part.open();
        try {
          var done = 0;
          while (done < offset) {
            final want = offset - done < 1 << 20 ? offset - done : 1 << 20;
            download.hasher!.add(await reader.read(want));
            done += want;
            download.connection.touch();
          }
        } finally {
          await reader.close();
        }
      }
      download
        ..received = offset
        ..partPath = accept.partPath
        ..finalPath = accept.finalPath;
      if (download.finished.isCompleted) return;
      download.connection.send(
        FileAcceptPacket(
          _header(download.connection.peerId),
          fileId: offer.fileId,
          offset: offset,
        ),
      );
      _emit(TransferStarted(offer.fileId, offset: offset));
      if (offset == offer.fileSize) await _finishDownload(download);
    } on FileSystemException catch (e) {
      download.connection.send(
        FileCancelPacket(
          _header(download.connection.peerId),
          fileId: offer.fileId,
          reason: FileCancelReason.error,
        ),
      );
      await download.connection.finish('storage error');
      await _endDownload(
        download,
        TransferFailed(TransferFailure.storage, e.message),
      );
    }
  }

  Future<void> _onDownloadFrame(_Download download, DataFrame frame) async {
    if (download.finished.isCompleted) return;
    final offer = download.offer;
    switch (frame) {
      case ChunkFrame(:final bytes):
        final file = download.file;
        if (file == null || download.verifying) {
          return _protocolError(download, 'data before FILE_ACCEPT');
        }
        if (download.received + bytes.length > offer.fileSize) {
          return _protocolError(download, 'more data than offered');
        }
        try {
          await file.writeFrom(bytes);
        } on FileSystemException catch (e) {
          download.connection.send(
            FileCancelPacket(
              _header(download.connection.peerId),
              fileId: offer.fileId,
              reason: FileCancelReason.error,
            ),
          );
          await download.connection.finish('storage error');
          return _endDownload(
            download,
            TransferFailed(TransferFailure.storage, e.message),
          );
        }
        download.hasher!.add(bytes);
        download.received += bytes.length;
        final now = clock.now();
        if (now.difference(download.lastProgress) >= timing.progressInterval) {
          download.lastProgress = now;
          _emit(TransferProgressed(offer.fileId, bytes: download.received));
        }
        if (download.received == offer.fileSize) {
          await _finishDownload(download);
        }
      case PacketFrame(packet: FileCancelPacket(:final reason)):
        download.connection.close('stopped by sender');
        await _endDownload(download, StoppedByPeer(reason));
      case PacketFrame(:final packet):
        await _protocolError(download, packet.type);
    }
  }

  /// All bytes are in: verify, sync, rename, confirm.
  Future<void> _finishDownload(_Download download) async {
    final offer = download.offer;
    download.verifying = true;
    _emit(TransferProgressed(offer.fileId, bytes: download.received));
    download.hasher!.close();
    final actual = download.digest.value.toString();
    final connection = download.connection;
    final file = download.file!;
    if (actual != offer.sha256) {
      await file.close().catchError((Object _) => file);
      download.file = null;
      await _deletePart(download);
      connection.send(
        FileCancelPacket(
          _header(connection.peerId),
          fileId: offer.fileId,
          reason: FileCancelReason.checksumMismatch,
        ),
      );
      await connection.finish('checksum mismatch');
      return _endDownload(
        download,
        const TransferFailed(TransferFailure.checksumMismatch),
      );
    }
    try {
      await file.flush(); // fsync before the rename makes it visible
      await file.close();
      download.file = null;
      final target = File(download.finalPath!);
      await target.parent.create(recursive: true);
      await File(download.partPath!).rename(target.path);
    } on FileSystemException catch (e) {
      connection.send(
        FileCancelPacket(
          _header(connection.peerId),
          fileId: offer.fileId,
          reason: FileCancelReason.error,
        ),
      );
      await connection.finish('storage error');
      return _endDownload(
        download,
        TransferFailed(TransferFailure.storage, e.message),
      );
    }
    connection.send(
      FileCompletePacket(
        _header(connection.peerId),
        fileId: offer.fileId,
        sha256: actual,
      ),
    );
    await connection.finish('complete');
    await _endDownload(download, const TransferCompleted());
  }

  Future<void> _protocolError(_Download download, String detail) async {
    download.connection.send(
      FileCancelPacket(
        _header(download.connection.peerId),
        fileId: download.offer.fileId,
        reason: FileCancelReason.error,
      ),
    );
    await download.connection.finish('protocol error');
    await _endDownload(
      download,
      TransferFailed(TransferFailure.protocol, detail),
    );
  }

  Future<void> _stopDownload(
    _Download download,
    FileCancelReason reason,
  ) async {
    if (download.finished.isCompleted) return;
    if (!download.answer.isCompleted) {
      download.answer.complete(const RejectOffer(FileRejectReason.declined));
      return;
    }
    download.connection.send(
      FileCancelPacket(
        _header(download.connection.peerId),
        fileId: download.offer.fileId,
        reason: reason,
      ),
    );
    await download.connection.finish('stopped');
    await _endDownload(download, StoppedHere(reason));
  }

  Future<void> _endDownload(_Download download, TransferOutcome outcome) async {
    if (download.finished.isCompleted) return;
    download.finished.complete();
    final file = download.file;
    download.file = null;
    await file?.close().catchError((Object _) => file);
    final cancelled = switch (outcome) {
      StoppedHere(reason: FileCancelReason.cancelled) ||
      StoppedByPeer(reason: FileCancelReason.cancelled) => true,
      _ => false,
    };
    if (cancelled) await _deletePart(download);
    if (identical(_downloads[download.offer.fileId], download)) {
      _downloads.remove(download.offer.fileId);
    }
    download.connection.close('done');
    _emit(
      TransferEnded(download.offer.fileId, outcome, bytes: download.received),
    );
  }

  Future<void> _deletePart(_Download download) async {
    final path = download.partPath;
    if (path == null) return;
    try {
      final part = File(path);
      if (part.existsSync()) await part.delete();
    } on FileSystemException {
      // Cleaned up by Storage later.
    }
  }
}

/// One file being sent.
final class _Upload {
  _Upload(this.request);

  final UploadRequest request;
  DataConnection? connection;
  RandomAccessFile? file;
  int sent = 0;

  /// Set by [TransferEngine.stop]; checked between chunks.
  FileCancelReason? stopRequested;

  /// The receiver sent FILE_CANCEL.
  FileCancelReason? peerStop;

  final Queue<Packet> _inbox = Queue();
  Completer<void>? _waiting;

  Future<void> onFrame(DataFrame frame) async {
    switch (frame) {
      case PacketFrame(:final packet):
        if (packet case FileCancelPacket(:final reason)) peerStop = reason;
        _inbox.add(packet);
      case ChunkFrame():
        // Receivers never send file data.
        connection?.close('file data from the receiver');
    }
    wake();
  }

  void wake() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  /// The next packet from the receiver, or null if the connection closed
  /// or [timeout] passed.
  Future<Packet?> next(Duration timeout) async {
    final deadline = clock.now().add(timeout);
    while (_inbox.isEmpty) {
      final connection = this.connection;
      if (connection == null || connection.isClosed) return null;
      if (stopRequested != null) return null;
      final left = deadline.difference(clock.now());
      if (left <= Duration.zero) return null;
      final waiting = _waiting = Completer<void>();
      try {
        await waiting.future.timeout(
          left < const Duration(milliseconds: 200)
              ? left
              : const Duration(milliseconds: 200),
        );
      } on TimeoutException {
        // Check stop requests and the deadline again.
      }
    }
    return _inbox.removeFirst();
  }
}

/// One file being received.
final class _Download {
  _Download(this.offer, this.connection);

  final FileOfferPacket offer;
  final DataConnection connection;
  final Completer<OfferAnswer> answer = Completer();
  final Completer<void> finished = Completer();
  // Closed when the last byte is verified.
  // ignore: close_sinks
  final _DigestSink digest = _DigestSink();
  // ignore: close_sinks
  ByteConversionSink? hasher;
  RandomAccessFile? file;
  String? partPath;
  String? finalPath;
  int received = 0;
  bool verifying = false;
  DateTime lastProgress = DateTime.fromMillisecondsSinceEpoch(0);
}

final class _DigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value => _value!;

  @override
  void add(Digest data) => _value = data;

  @override
  void close() {}
}
