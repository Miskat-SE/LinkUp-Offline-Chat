import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/network/protocol/frame_codec.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

/// A frame on a data connection after the handshake.
sealed class DataFrame {
  const DataFrame();
}

final class PacketFrame extends DataFrame {
  const PacketFrame(this.packet);

  final Packet packet;
}

final class ChunkFrame extends DataFrame {
  const ChunkFrame(this.bytes);

  final Uint8List bytes;
}

/// The other side broke the data connection's handshake.
final class DataHandshakeException implements Exception {
  const DataHandshakeException(this.reason);

  final String reason;

  @override
  String toString() => 'DataHandshakeException: $reason';
}

/// One file data connection (PROTOCOL.md §4.4): HELLO handshake, then
/// control packets and binary chunks.
///
/// Frames are handed to `onFrame` one at a time, and reading pauses until
/// each is handled, so a slow disk slows the sender down through TCP
/// instead of filling memory. Data connections are strict: any malformed
/// frame closes them.
final class DataConnection {
  DataConnection._(this._socket, this._selfId, this._expectedPeerId)
    : address = _socket.remoteAddress.address {
    _subscription = _socket.listen(
      _onData,
      onError: (Object _) => close('socket error'),
      onDone: () => close('closed by peer'),
      cancelOnError: true,
    );
    unawaited(_socket.done.catchError((Object _) {}));
  }

  /// Sends [hello], waits for the other side's, and starts handing frames
  /// to [onFrame]. Throws [DataHandshakeException]; the socket is closed.
  static Future<DataConnection> open({
    required Socket socket,
    required HelloPacket hello,
    required Future<void> Function(DataFrame frame) onFrame,
    required Duration helloTimeout,
    required Duration idleTimeout,
    String? expectedPeerId,
  }) async {
    final connection = DataConnection._(
      socket,
      hello.header.senderId,
      expectedPeerId,
    ).._onFrame = onFrame;
    connection.send(hello);
    try {
      await connection._hello.future.timeout(helloTimeout);
    } on TimeoutException {
      connection.close('no HELLO');
      throw const DataHandshakeException('no HELLO in time');
    }
    connection._watchIdle(idleTimeout);
    return connection;
  }

  final Socket _socket;
  final String _selfId;
  final String? _expectedPeerId;
  final String address;

  late final StreamSubscription<List<int>> _subscription;
  late Future<void> Function(DataFrame frame) _onFrame;
  final FrameDecoder _decoder = FrameDecoder();
  final Completer<HelloPacket> _hello = Completer();
  final Completer<String> _closed = Completer();
  Future<void> _handling = Future.value();
  DateTime _lastActivity = clock.now();
  Timer? _idle;

  /// The other side's HELLO (valid after [open] returns).
  late final HelloPacket peerHello;

  String get peerId => peerHello.header.senderId;

  bool get isClosed => _closed.isCompleted;

  /// Completes with the reason when the connection closes.
  Future<String> get closed => _closed.future;

  void send(Packet packet) {
    if (isClosed) return;
    _socket.add(
      FrameCodec.encode(FrameKind.control, PacketCodec.encode(packet)),
    );
  }

  void sendChunk(List<int> bytes) {
    if (isClosed) return;
    _lastActivity = clock.now();
    _socket.add(FrameCodec.encode(FrameKind.fileChunk, bytes));
  }

  /// Waits until everything added so far is handed to the OS: the
  /// sender's backpressure.
  Future<void> flush() async {
    if (isClosed) return;
    try {
      await _socket.flush();
      _lastActivity = clock.now();
    } on Object {
      close('write failed');
    }
  }

  /// Sends what is buffered, then closes.
  Future<void> finish(String reason) async {
    await flush();
    close(reason);
  }

  void close(String reason) {
    if (isClosed) return;
    _closed.complete(reason);
    _idle?.cancel();
    unawaited(_subscription.cancel());
    _socket.destroy();
    if (!_hello.isCompleted) {
      _hello.completeError(DataHandshakeException(reason));
      unawaited(_hello.future.then((_) {}, onError: (Object _) {}));
    }
  }

  void _onData(List<int> data) {
    _lastActivity = clock.now();
    final List<Frame> frames;
    try {
      frames = _decoder.add(data);
    } on FrameException {
      close('bad framing');
      return;
    }
    if (frames.isEmpty) return;
    // Hold further reads until these frames are handled (backpressure).
    _subscription.pause();
    _handling = _handling.then((_) async {
      for (final frame in frames) {
        if (isClosed) return;
        await _dispatch(frame);
      }
    });
    unawaited(
      _handling.then((_) {
        if (!isClosed) _subscription.resume();
      }, onError: (Object _) => close('frame handler failed')),
    );
  }

  Future<void> _dispatch(Frame frame) async {
    if (frame.kind == FrameKind.fileChunk) {
      if (!_hello.isCompleted) {
        close('file data before HELLO');
        return;
      }
      await _onFrame(ChunkFrame(frame.body));
      return;
    }
    final result = PacketCodec.decode(frame.body);
    if (result is! Decoded) {
      close('malformed packet');
      return;
    }
    final packet = result.packet;
    if (!_hello.isCompleted) {
      _onHello(packet);
      return;
    }
    if (packet.header.senderId != peerId) {
      close('sender ID does not match HELLO');
      return;
    }
    await _onFrame(PacketFrame(packet));
  }

  void _onHello(Packet packet) {
    final String? problem;
    if (packet is! HelloPacket) {
      problem = '${packet.type} before HELLO';
    } else if (packet.header.senderId == _selfId) {
      problem = 'connected to itself';
    } else if (_expectedPeerId != null &&
        packet.header.senderId != _expectedPeerId) {
      problem = 'a different device answered';
    } else if (!packet.announcement.compatible) {
      problem = 'incompatible protocol';
    } else {
      problem = null;
    }
    if (problem != null) {
      close(problem);
      return;
    }
    peerHello = packet as HelloPacket;
    _hello.complete(packet);
  }

  void _watchIdle(Duration idleTimeout) {
    final step = idleTimeout < const Duration(seconds: 5)
        ? idleTimeout
        : const Duration(seconds: 5);
    _idle = Timer.periodic(step, (_) {
      if (clock.now().difference(_lastActivity) >= idleTimeout) {
        close('timed out');
      }
    });
  }

  /// Marks the connection as busy while this side works without sending,
  /// such as re-hashing a partial file before accepting.
  void touch() => _lastActivity = clock.now();
}
