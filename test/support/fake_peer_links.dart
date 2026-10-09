import 'dart:async';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// [PeerLinks] for widget tests: every endpoint connects at once, except
/// devices listed in [refused], which show as unreachable. Real TCP is
/// tested separately on loopback sockets.
final class FakePeerLinks implements PeerLinks {
  final Set<String> refused = {};

  /// The file port other devices announce (null: they can't receive).
  int? peerFilePort = 28762;
  final List<(String, Packet)> sent = [];
  final StreamController<LinksSnapshot> _snapshots =
      StreamController<LinksSnapshot>.broadcast();
  final StreamController<PeerPacket> _packets =
      StreamController<PeerPacket>.broadcast();
  LinksSnapshot _current = LinksSnapshot.initial;

  @override
  LinksSnapshot get current => _current;

  @override
  Stream<LinksSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PeerPacket> get packets => _packets.stream;

  /// Delivers [packet] as if [from] had sent it.
  void receive(String from, Packet packet) =>
      _packets.add(PeerPacket(from, packet));

  @override
  Future<int?> start() async {
    _set(listeningPort: 28761);
    return 28761;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<int?> resetNetwork() async => 28761;

  @override
  void updateEndpoints(List<PeerEndpoint> endpoints) {
    _set(
      listeningPort: 28761,
      links: {
        for (final e in endpoints)
          if (!refused.contains(e.deviceId))
            e.deviceId: LinkInfo(
              peerId: e.deviceId,
              peerName: '',
              address: e.address,
              direction: ConnectionDirection.outbound,
              connectedAt: clock.now(),
              rttMs: 3,
              filePort: peerFilePort,
            ),
      },
      unreachable: {
        for (final e in endpoints)
          if (refused.contains(e.deviceId)) e.deviceId,
      },
    );
  }

  @override
  bool send(String deviceId, Packet packet) {
    if (!_current.links.containsKey(deviceId)) return false;
    sent.add((deviceId, packet));
    return true;
  }

  @override
  void sendToAll(Packet Function(String deviceId) packetFor) {
    for (final id in _current.links.keys) {
      send(id, packetFor(id));
    }
  }

  /// Connects [deviceId] directly (for tests without discovery).
  void connect(String deviceId, {String address = '192.168.0.20'}) => _set(
    links: {
      ..._current.links,
      deviceId: LinkInfo(
        peerId: deviceId,
        peerName: '',
        address: address,
        direction: ConnectionDirection.outbound,
        connectedAt: clock.now(),
        rttMs: 3,
        filePort: peerFilePort,
      ),
    },
  );

  void disconnect(String deviceId) =>
      _set(links: {..._current.links}..remove(deviceId));

  void _set({
    int? listeningPort,
    Map<String, LinkInfo>? links,
    Set<String>? unreachable,
  }) {
    _current = LinksSnapshot(
      listeningPort: listeningPort,
      links: links ?? _current.links,
      unreachable: unreachable ?? _current.unreachable,
      stats: const LinkStats(),
    );
    _snapshots.add(_current);
  }

  /// The file port this device announced.
  int? filePort;

  @override
  void setFilePort(int? port) => filePort = port;
}
