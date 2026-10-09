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
}
