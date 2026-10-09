import 'dart:async';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// Several phones joined by in-memory connections, for broadcast tests.
/// Any pair can be connected or cut, and a phone's outgoing packets can be
/// lost.
final class LinkedMesh {
  LinkedMesh(Iterable<String> ids) {
    for (final id in ids) {
      nodes[id] = MeshLink._(this, id);
    }
  }

  final Map<String, MeshLink> nodes = {};
  final Set<(String, String)> _connected = {};

  MeshLink operator [](String id) => nodes[id]!;

  static (String, String) _pair(String a, String b) =>
      a.compareTo(b) < 0 ? (a, b) : (b, a);

  bool connected(String a, String b) => _connected.contains(_pair(a, b));

  void connect(String a, String b) {
    _connected.add(_pair(a, b));
    nodes[a]!._emit();
    nodes[b]!._emit();
  }

  void disconnect(String a, String b) {
    _connected.remove(_pair(a, b));
    nodes[a]!._emit();
    nodes[b]!._emit();
  }

  /// Connects every pair.
  void connectAll() {
    final ids = nodes.keys.toList();
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        _connected.add(_pair(ids[i], ids[j]));
      }
    }
    for (final node in nodes.values) {
      node._emit();
    }
  }
}

final class MeshLink implements PeerLinks {
  MeshLink._(this._mesh, this.id);

  final LinkedMesh _mesh;
  final String id;

  /// Name and file port this phone announces to the others.
  String name = '';
  int? announcedFilePort = 28762;
  String address = '127.0.0.1';

  /// Packets this phone sends are silently lost.
  bool dropOutgoing = false;

  /// Everything this phone sent, delivered or not.
  final List<(String, Packet)> sent = [];

  final StreamController<PeerPacket> _packets =
      StreamController<PeerPacket>.broadcast();
  final StreamController<LinksSnapshot> _snapshots =
      StreamController<LinksSnapshot>.broadcast();

  /// Delivers [packet] as if [from] sent it.
  void inject(String from, Packet packet) =>
      _packets.add(PeerPacket(from, packet));

  @override
  LinksSnapshot get current => LinksSnapshot(
    listeningPort: 1,
    links: {
      for (final other in _mesh.nodes.values)
        if (other.id != id && _mesh.connected(id, other.id))
          other.id: LinkInfo(
            peerId: other.id,
            peerName: other.name,
            address: other.address,
            direction: ConnectionDirection.outbound,
            connectedAt: clock.now(),
            rttMs: 1,
            filePort: other.announcedFilePort,
          ),
    },
    unreachable: const {},
    stats: const LinkStats(),
  );

  @override
  Stream<LinksSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<PeerPacket> get packets => _packets.stream;

  @override
  bool send(String deviceId, Packet packet) {
    final other = _mesh.nodes[deviceId];
    if (other == null || !_mesh.connected(id, deviceId)) return false;
    sent.add((deviceId, packet));
    if (!dropOutgoing) other._packets.add(PeerPacket(id, packet));
    return true;
  }

  /// Packets of type [T] sent to [deviceId].
  Iterable<T> sentTo<T extends Packet>(String deviceId) => [
    for (final (to, packet) in sent)
      if (to == deviceId && packet is T) packet,
  ];

  @override
  void sendToAll(Packet Function(String deviceId) packetFor) {
    for (final other in current.links.keys) {
      send(other, packetFor(other));
    }
  }

  @override
  Future<int?> start() async => 1;

  @override
  Future<void> stop() async {}

  @override
  Future<int?> resetNetwork() async => 1;

  @override
  void updateEndpoints(List<PeerEndpoint> endpoints) {}

  @override
  void setFilePort(int? port) => announcedFilePort = port;

  void _emit() => _snapshots.add(current);
}
