import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/inbound_limits.dart';
import 'package:resqmesh/core/network/protocol/frame_codec.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

enum ConnectionDirection { outbound, inbound }

/// Connection timings (PROJECT_PLAN.md §5.5 rule 8). Tests shorten them.
final class ConnectionTiming {
  const ConnectionTiming({
    this.connectTimeout = const Duration(seconds: 5),
    this.helloTimeout = const Duration(seconds: 5),
    this.pingInterval = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 45),
    this.reconnectBase = const Duration(seconds: 1),
    this.reconnectMax = const Duration(seconds: 30),
    this.dialGrace = const Duration(seconds: 3),
  });

  final Duration connectTimeout;

  /// Both sides must send HELLO within this time.
  final Duration helloTimeout;
  final Duration pingInterval;

  /// No frame at all for this long closes the connection (2 missed PONGs).
  final Duration idleTimeout;
  final Duration reconnectBase;
  final Duration reconnectMax;

  /// How long the device with the higher ID waits for the other side to
  /// dial before dialling itself (§5.5 rule 7).
  final Duration dialGrace;
}

/// The other side broke the handshake rules.
final class HandshakeException implements Exception {
  const HandshakeException(this.reason);

  final String reason;

  @override
  String toString() => 'HandshakeException: $reason';
}

/// One control connection to another device (PROTOCOL.md §1, §4.5): the
/// HELLO handshake, framing, validation and keep-alive. Packets other than
/// PING/PONG come out of [packets].
final class PeerConnection {
  PeerConnection._(
    this._socket,
    this.direction,
    this._selfId,
    this._selfName,
    this._expectedPeerId,
    this._timing,
    this._logger,
  ) : address = _socket.remoteAddress.address {
    _subscription = _socket.listen(
      _onData,
      onError: (Object _) => close('socket error'),
      onDone: () => close('closed by peer'),
      cancelOnError: true,
    );
    // Errors from writing to a dead socket surface here, not at add().
    unawaited(_socket.done.catchError((Object _) {}));
  }

  /// Sends [hello] and waits for the other side's HELLO. Throws
  /// [HandshakeException] on timeout or a bad HELLO; the socket is closed.
  static Future<PeerConnection> open({
    required Socket socket,
    required ConnectionDirection direction,
    required HelloPacket hello,
    required ConnectionTiming timing,
    required AppLogger logger,
    String? expectedPeerId,
  }) async {
    final connection = PeerConnection._(
      socket,
      direction,
      hello.header.senderId,
      hello.header.senderName,
      expectedPeerId,
      timing,
      logger,
    );
    connection.send(hello);
    try {
      await connection._hello.future.timeout(timing.helloTimeout);
    } on TimeoutException {
      connection.close('no HELLO');
      throw const HandshakeException('no HELLO in time');
    } on HandshakeException {
      rethrow;
    }
    connection._startKeepAlive();
    return connection;
  }

  final Socket _socket;
  final ConnectionDirection direction;
  final String _selfId;
  final String _selfName;
  final String? _expectedPeerId;
  final ConnectionTiming _timing;
  final AppLogger _logger;
  final String address;

  late final StreamSubscription<List<int>> _subscription;
  final FrameDecoder _decoder = FrameDecoder();
  final Completer<HelloPacket> _hello = Completer();
  final Completer<String> _closed = Completer();
  final StreamController<Packet> _packets =
      StreamController<Packet>.broadcast();
  final Random _random = Random();
  Timer? _keepAlive;
  int _malformedInARow = 0;

  /// Far more than any real use (receipts are batched 100 to a packet), so
  /// a device flooding packets is cut off (P9.3).
  final TokenBucket _packetBudget = TokenBucket(capacity: 2000, perSecond: 200);
  int? _pendingNonce;
  DateTime? _pingSentAt;
  DateTime _lastReceived = clock.now();
  final DateTime connectedAt = clock.now();

  /// Round-trip time of the last PING, for diagnostics.
  int? rttMs;

  void Function()? _updated;

  /// Called when the other side re-sends HELLO.
  set onUpdated(void Function()? callback) => _updated = callback;

  /// The other side's HELLO (valid after [open] returns).
  HelloPacket get peerHello => _helloPacket!;
  HelloPacket? _helloPacket;

  String get peerId => peerHello.header.senderId;

  /// Which device opened this connection.
  String get initiatorId =>
      direction == ConnectionDirection.outbound ? _selfId : peerId;

  Stream<Packet> get packets => _packets.stream;

  /// Completes with the reason when the connection closes.
  Future<String> get closed => _closed.future;

  bool get isClosed => _closed.isCompleted;

  void send(Packet packet) {
    if (isClosed) return;
    _socket.add(
      FrameCodec.encode(FrameKind.control, PacketCodec.encode(packet)),
    );
  }

  void close(String reason) {
    if (isClosed) return;
    _closed.complete(reason);
    _keepAlive?.cancel();
    unawaited(_subscription.cancel());
    _socket.destroy();
    unawaited(_packets.close());
    if (!_hello.isCompleted) {
      _hello.completeError(HandshakeException(reason));
      // Nobody may be waiting any more; don't report it as unhandled.
      unawaited(_hello.future.then((_) {}, onError: (Object _) {}));
    }
  }

  void _onData(List<int> chunk) {
    _lastReceived = clock.now();
    final List<Frame> frames;
    try {
      frames = _decoder.add(chunk);
    } on FrameException catch (e) {
      _logger.warning(LogTag.network, 'Bad framing, closing', {
        'address': address,
        'reason': e.message,
      });
      close('bad framing');
      return;
    }
    for (final frame in frames) {
      if (isClosed) return;
      if (frame.kind != FrameKind.control) {
        close('file data on a control connection');
        return;
      }
      _onPacket(PacketCodec.decode(frame.body));
    }
  }

  void _onPacket(DecodeResult result) {
    switch (result) {
      case Decoded(:final packet):
        _malformedInARow = 0;
        if (!_packetBudget.take()) {
          _logger.warning(LogTag.network, 'Too many packets, closing', {
            'address': address,
          });
          close('too many packets');
          return;
        }
        if (_helloPacket == null) {
          _onHello(packet);
        } else if (packet.header.senderId != peerId) {
          // Someone else's ID on this connection: drop it (spec §28).
          _malformed('sender ID does not match HELLO');
        } else {
          _onPeerPacket(packet);
        }
      case UnknownType():
        break; // Newer peer; ignore (PROTOCOL.md §6).
      case Malformed(:final reason):
        _malformed(reason);
      case UnsupportedVersion() || TooLarge() || Foreign():
        _malformed(result.runtimeType.toString());
    }
  }

  void _onHello(Packet packet) {
    if (packet is! HelloPacket) {
      _hello.completeError(HandshakeException('${packet.type} before HELLO'));
      close('no HELLO first');
      return;
    }
    final id = packet.header.senderId;
    final String? problem;
    if (id == _selfId) {
      problem = 'connected to itself';
    } else if (_expectedPeerId != null && id != _expectedPeerId) {
      problem = 'a different device answered';
    } else if (!packet.announcement.compatible) {
      problem = 'incompatible protocol';
    } else {
      problem = null;
    }
    if (problem != null) {
      _hello.completeError(HandshakeException(problem));
      close(problem);
      return;
    }
    _helloPacket = packet;
    _hello.complete(packet);
  }

  void _onPeerPacket(Packet packet) {
    switch (packet) {
      case HelloPacket():
        // A fresh HELLO on an open connection updates the announcement,
        // e.g. a new file port.
        if (packet.announcement.compatible) {
          _helloPacket = packet;
          _updated?.call();
        }
      case PingPacket(:final nonce):
        send(PongPacket(_header(), nonce: nonce));
      case PongPacket(:final nonce):
        final sentAt = _pingSentAt;
        if (nonce == _pendingNonce && sentAt != null) {
          rttMs = clock.now().difference(sentAt).inMilliseconds;
          _pendingNonce = null;
        }
      default:
        if (!_packets.isClosed) _packets.add(packet);
    }
  }

  void _malformed(String reason) {
    _malformedInARow++;
    _logger.debug(LogTag.network, 'Malformed frame', {
      'address': address,
      'reason': reason,
    });
    if (_malformedInARow >= 3) close('3 malformed frames');
  }

  void _startKeepAlive() {
    _keepAlive = Timer.periodic(_timing.pingInterval, (_) {
      if (clock.now().difference(_lastReceived) >= _timing.idleTimeout) {
        close('timed out');
        return;
      }
      final nonce = _random.nextInt(0x7FFFFFFF);
      _pendingNonce = nonce;
      _pingSentAt = clock.now();
      send(PingPacket(_header(), nonce: nonce));
    });
  }

  PacketHeader _header() => PacketHeader.create(
    senderId: _selfId,
    senderName: _selfName,
    receiverId: peerId,
  );
}

/// Opens a TCP connection; replaceable in tests.
typedef SocketConnector = Future<Socket> Function(
  String address,
  int port,
  Duration timeout,
);

Future<Socket> connectSocket(String address, int port, Duration timeout) =>
    Socket.connect(address, port, timeout: timeout);
