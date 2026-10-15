import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/byte_link.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/inbound_limits.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// [PeerLinks] over real TCP sockets (PROJECT_PLAN.md §5.5).
///
/// - Listens on the preferred port (28761), or an ephemeral one if taken.
/// - The device with the lower ID dials; the other dials too only if no
///   connection appears within the grace period (asymmetric discovery).
/// - If both connections still happen, the one opened by the lower ID is
///   kept (rule 7).
/// - Lost connections are redialled with exponential backoff.
final class ConnectionManager implements PeerLinks {
  ConnectionManager({
    required this._self,
    required this._logger,
    int preferredPort = ProtocolConstants.tcpPort,
    this._timing = const ConnectionTiming(),
    SocketConnector connect = connectSocket,
    InternetAddress? bindAddress,
    LinkTransport? transport,
    this._maxLinks = 32,
    this._maxPending = 8,
  }) : _preferredPort = preferredPort {
    _transport =
        transport ??
        TcpTransport(
          preferredPort: preferredPort,
          bindAddress: bindAddress,
          connector: connect,
          onBindError: _error,
        );
  }

  final SelfInfo Function() _self;
  final AppLogger _logger;
  final int _preferredPort;
  final ConnectionTiming _timing;
  late final LinkTransport _transport;
  final int _maxLinks;

  /// Connections still in their HELLO handshake (P9.3): a slow or silent
  /// client holds one of these for at most the handshake timeout.
  final int _maxPending;
  int _pending = 0;

  /// New connections per source address.
  final RateLimiter _accepts = RateLimiter(
    limit: 20,
    window: const Duration(minutes: 1),
  );
  int _refused = 0;

  /// Where others reach this phone: a TCP port or a Bluetooth channel.
  int? _port;
  Timer? _tick;
  bool _running = false;

  final Map<String, PeerConnection> _links = {};
  final Set<String> _dialling = {};
  final Map<String, _Backoff> _backoff = {};
  final Map<String, DateTime> _waitingSince = {};
  List<PeerEndpoint> _endpoints = const [];
  int? _filePort;

  final StreamController<LinksSnapshot> _snapshots =
      StreamController<LinksSnapshot>.broadcast();
  final StreamController<PeerPacket> _packets =
      StreamController<PeerPacket>.broadcast();
  LinksSnapshot _current = LinksSnapshot.initial;

  int _dials = 0;
  int _dialFailures = 0;
  int _accepted = 0;
  int _handshakeFailures = 0;
  int _duplicatesClosed = 0;
  final List<String> _errors = [];

  @override
  LinksSnapshot get current => _current;

  @override
  Stream<LinksSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PeerPacket> get packets => _packets.stream;

  @override
  Future<int?> start() async {
    if (_running) return _port;
    _running = true;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _dialDue());
    return _listen();
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _tick?.cancel();
    await _closeAll('app stopped');
    _emit();
  }

  @override
  Future<int?> resetNetwork() async {
    if (!_running) return null;
    await _closeAll('network changed');
    _backoff.clear();
    _waitingSince.clear();
    return _listen();
  }

  @override
  void updateEndpoints(List<PeerEndpoint> endpoints) {
    _endpoints = endpoints;
    final ids = {for (final e in endpoints) e.deviceId};
    _waitingSince.removeWhere((id, _) => !ids.contains(id));
    _dialDue();
    _emit();
  }

  @override
  bool send(String deviceId, Packet packet) {
    final link = _links[deviceId];
    if (link == null || link.isClosed) return false;
    link.send(packet);
    return true;
  }

  @override
  void sendToAll(Packet Function(String deviceId) packetFor) {
    for (final id in _links.keys.toList()) {
      send(id, packetFor(id));
    }
  }

  @override
  void setFilePort(int? port) {
    if (port == _filePort) return;
    _filePort = port;
    final self = _self();
    if (!self.canAnnounce) return;
    for (final link in _links.values) {
      link.send(_hello(self));
    }
  }

  // ----------------------------------------------------------------- server

  Future<int?> _listen() async {
    final port = _port = await _transport.listen(
      (link) => unawaited(_accept(link)),
    );
    if (port != null) {
      _logger.info(LogTag.network, 'Listening for connections', {'port': port});
    }
    _emit();
    return port;
  }

  Future<void> _closeAll(String reason) async {
    await _transport.close();
    _port = null;
    for (final link in _links.values.toList()) {
      link.close(reason);
    }
    _links.clear();
  }

  Future<void> _accept(ByteLink socket) async {
    final self = _self();
    if (!_running || !self.canAnnounce || _links.length >= _maxLinks) {
      socket.destroy();
      return;
    }
    if (_pending >= _maxPending || !_accepts.allow(socket.address)) {
      _refused++;
      socket.destroy();
      _emit();
      return;
    }
    _pending++;
    try {
      final link = await PeerConnection.open(
        link: socket,
        direction: ConnectionDirection.inbound,
        hello: _hello(self),
        timing: _timing,
        logger: _logger,
      );
      _accepted++;
      _register(link);
    } on HandshakeException catch (e) {
      _handshakeFailures++;
      _error('Inbound handshake failed: ${e.reason}');
      _emit();
    } finally {
      _pending--;
    }
  }

  // ---------------------------------------------------------------- dialling

  void _dialDue() {
    if (!_running) return;
    final self = _self();
    if (!self.canAnnounce || _port == null) return;
    final now = clock.now();
    for (final endpoint in _endpoints) {
      final id = endpoint.deviceId;
      if (id == self.deviceId) continue;
      if (_links.containsKey(id) || _dialling.contains(id)) continue;
      if (!(_backoff[id]?.due(now) ?? true)) continue;
      // The lower ID dials at once; the higher one gives it a head start.
      if (self.deviceId.compareTo(id) > 0) {
        final since = _waitingSince.putIfAbsent(id, () => now);
        if (now.difference(since) < _timing.dialGrace) continue;
      }
      unawaited(_dial(endpoint, self));
    }
  }

  Future<void> _dial(PeerEndpoint endpoint, SelfInfo self) async {
    final id = endpoint.deviceId;
    _dialling.add(id);
    _dials++;
    try {
      // PeerConnection owns the socket and closes it.
      // ignore: close_sinks
      final socket = await _transport.connect(
        endpoint.address,
        endpoint.port,
        _timing.connectTimeout,
      );
      final link = await PeerConnection.open(
        link: socket,
        direction: ConnectionDirection.outbound,
        hello: _hello(self),
        timing: _timing,
        logger: _logger,
        expectedPeerId: id,
      );
      _register(link);
    } on Object catch (e) {
      if (e is! SocketException &&
          e is! HandshakeException &&
          e is! LinkException) {
        rethrow;
      }
      _dialFailures++;
      final backoff = _backoff.putIfAbsent(id, () => _Backoff(_timing));
      backoff.failed(clock.now());
      _error(
        'Connect to ${id.substring(0, 4)} at ${endpoint.address} failed '
        '(${backoff.failures}x): '
        '${switch (e) {
          HandshakeException(:final reason) => reason,
          LinkException(:final message) => message,
          _ => (e as SocketException).message,
        }}',
      );
    } finally {
      _dialling.remove(id);
      _emit();
    }
  }

  void _register(PeerConnection link) {
    if (!_running) {
      link.close('app stopped');
      return;
    }
    final id = link.peerId;
    final existing = _links[id];
    if (existing != null && !existing.isClosed) {
      // Rule 7: keep the connection opened by the lower device ID; between
      // two from the same side, keep the newer one.
      final preferred = _lowerOf(_self().deviceId, id);
      final keepNew =
          link.initiatorId == preferred || existing.initiatorId != preferred;
      final (keep, drop) = keepNew ? (link, existing) : (existing, link);
      _duplicatesClosed++;
      drop.close('duplicate connection');
      if (identical(keep, existing)) return;
    }
    _links[id] = link;
    _backoff.remove(id);
    _waitingSince.remove(id);
    _logger.info(LogTag.network, 'Connected', {
      'device': id.substring(0, 4),
      'address': link.address,
      'direction': link.direction.name,
    });
    link
      ..onUpdated = _emit
      ..packets.listen((packet) => _packets.add(PeerPacket(id, packet)));
    unawaited(
      link.closed.then((reason) {
        if (!identical(_links[id], link)) return;
        _links.remove(id);
        _logger.info(LogTag.network, 'Disconnected', {
          'device': id.substring(0, 4),
          'reason': reason,
        });
        // Redial soon if discovery still sees it.
        _backoff[id] = _Backoff(_timing)..failed(clock.now());
        _emit();
      }),
    );
    _emit();
  }

  static String _lowerOf(String a, String b) => a.compareTo(b) <= 0 ? a : b;

  HelloPacket _hello(SelfInfo self) => HelloPacket(
    PacketHeader.create(senderId: self.deviceId, senderName: self.name!),
    Announcement(
      tcpPort: _port ?? _preferredPort,
      filePort: _filePort,
      appVersion: self.appVersion,
      nameClaimedAt: self.nameClaimedAt!,
    ),
  );

  // ------------------------------------------------------------------- state

  void _error(String message) {
    _logger.warning(LogTag.network, message);
    _errors.add('${clock.now().toIso8601String().substring(11, 19)} $message');
    if (_errors.length > 20) _errors.removeAt(0);
  }

  void _emit() {
    final endpointIds = {for (final e in _endpoints) e.deviceId};
    _current = LinksSnapshot(
      listeningPort: _port,
      links: {
        for (final link in _links.values)
          link.peerId: LinkInfo(
            peerId: link.peerId,
            peerName: link.peerHello.header.senderName,
            address: link.address,
            direction: link.direction,
            connectedAt: link.connectedAt,
            rttMs: link.rttMs,
            filePort: link.peerHello.announcement.filePort,
          ),
      },
      unreachable: {
        for (final entry in _backoff.entries)
          if (entry.value.failures >= 2 &&
              endpointIds.contains(entry.key) &&
              !_links.containsKey(entry.key))
            entry.key,
      },
      stats: LinkStats(
        dials: _dials,
        dialFailures: _dialFailures,
        accepted: _accepted,
        handshakeFailures: _handshakeFailures,
        duplicatesClosed: _duplicatesClosed,
        refused: _refused,
        recentErrors: List.unmodifiable(_errors),
      ),
    );
    if (!_snapshots.isClosed) _snapshots.add(_current);
  }
}

/// When a lost device may be dialled again ([ConnectionTiming.reconnectDelay]).
final class _Backoff {
  _Backoff(this._timing);

  final ConnectionTiming _timing;
  int failures = 0;
  DateTime? _next;

  void failed(DateTime now) {
    failures++;
    _next = now.add(_timing.reconnectDelay(failures));
  }

  bool due(DateTime now) => _next == null || !now.isBefore(_next!);
}
