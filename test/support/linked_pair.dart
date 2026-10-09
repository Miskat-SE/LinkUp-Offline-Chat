import 'dart:async';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// Two phones joined by an in-memory connection, for messaging tests.
/// The connection can be cut, and packets in either direction can be lost.
final class LinkedPair {
  LinkedPair(String idA, String idB) {
    a = PairLink._(this, idA);
    b = PairLink._(this, idB);
  }

  late final PairLink a;
  late final PairLink b;
  bool _connected = false;

  bool get connected => _connected;

  void connect() => _setConnected(true);

  void disconnect() => _setConnected(false);

  void _setConnected(bool value) {
    _connected = value;
    a._emit();
    b._emit();
  }

  PairLink _other(PairLink link) => identical(link, a) ? b : a;
}

final class PairLink implements PeerLinks {
  PairLink._(this._pair, this.id);

  final LinkedPair _pair;
  final String id;

  /// Packets this side sends are silently lost.
  bool dropOutgoing = false;

  /// Everything this side sent, delivered or not.
  final List<Packet> sent = [];

  final StreamController<PeerPacket> _packets =
      StreamController<PeerPacket>.broadcast();
  final StreamController<LinksSnapshot> _snapshots =
      StreamController<LinksSnapshot>.broadcast();

  /// Delivers [packet] as if [from] sent it (for spoofing tests).
  void inject(String from, Packet packet) =>
      _packets.add(PeerPacket(from, packet));

  @override
  LinksSnapshot get current {
    final other = _pair._other(this);
    return LinksSnapshot(
      listeningPort: 1,
      links: {
        if (_pair.connected)
          other.id: LinkInfo(
            peerId: other.id,
            peerName: '',
            address: '127.0.0.1',
            direction: ConnectionDirection.outbound,
            connectedAt: clock.now(),
            rttMs: 1,
          ),
      },
      unreachable: const {},
      stats: const LinkStats(),
    );
  }

  @override
  Stream<LinksSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PeerPacket> get packets => _packets.stream;

  @override
  bool send(String deviceId, Packet packet) {
    final other = _pair._other(this);
    if (!_pair.connected || deviceId != other.id) return false;
    sent.add(packet);
    if (!dropOutgoing) other._packets.add(PeerPacket(id, packet));
    return true;
  }

  @override
  void sendToAll(Packet Function(String deviceId) packetFor) =>
      send(_pair._other(this).id, packetFor(_pair._other(this).id));

  @override
  Future<int?> start() async => 1;

  @override
  Future<void> stop() async {}

  @override
  Future<int?> resetNetwork() async => 1;

  @override
  void updateEndpoints(List<PeerEndpoint> endpoints) {}

  void _emit() => _snapshots.add(current);
}
