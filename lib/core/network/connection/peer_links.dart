import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// Where to reach a discovered device over TCP.
final class PeerEndpoint {
  const PeerEndpoint({
    required this.deviceId,
    required this.address,
    required this.port,
  });

  final String deviceId;
  final String address;
  final int port;
}

/// One live control connection, for the UI and the developer screen.
final class LinkInfo {
  const LinkInfo({
    required this.peerId,
    required this.peerName,
    required this.address,
    required this.direction,
    required this.connectedAt,
    required this.rttMs,
  });

  final String peerId;
  final String peerName;
  final String address;
  final ConnectionDirection direction;
  final DateTime connectedAt;
  final int? rttMs;
}

final class LinkStats {
  const LinkStats({
    this.dials = 0,
    this.dialFailures = 0,
    this.accepted = 0,
    this.handshakeFailures = 0,
    this.duplicatesClosed = 0,
    this.recentErrors = const [],
  });

  final int dials;
  final int dialFailures;
  final int accepted;
  final int handshakeFailures;
  final int duplicatesClosed;
  final List<String> recentErrors;
}

final class LinksSnapshot {
  const LinksSnapshot({
    required this.listeningPort,
    required this.links,
    required this.unreachable,
    required this.stats,
  });

  static const initial = LinksSnapshot(
    listeningPort: null,
    links: {},
    unreachable: {},
    stats: LinkStats(),
  );

  /// The TCP port this device accepts connections on, or null.
  final int? listeningPort;

  /// Live connections by device ID.
  final Map<String, LinkInfo> links;

  /// Devices that are discovered but repeatedly failed to connect.
  final Set<String> unreachable;
  final LinkStats stats;
}

/// A packet received from a connected device.
final class PeerPacket {
  const PeerPacket(this.from, this.packet);

  final String from;
  final Packet packet;
}

/// Control connections to discovered devices (PROJECT_PLAN.md D5, §5.5).
abstract interface class PeerLinks {
  LinksSnapshot get current;

  Stream<LinksSnapshot> get snapshots;

  /// Packets other than the handshake and keep-alive (used from P4 on).
  Stream<PeerPacket> get packets;

  /// Starts listening; returns the TCP port actually bound.
  Future<int?> start();

  Future<void> stop();

  /// The devices discovery currently sees online. Links dials the ones it
  /// should and keeps them connected.
  void updateEndpoints(List<PeerEndpoint> endpoints);

  /// The local network changed: drop every connection and listen again.
  Future<int?> resetNetwork();

  /// Sends to a connected device; returns false if not connected.
  bool send(String deviceId, Packet packet);

  /// Sends to every connected device.
  void sendToAll(Packet Function(String deviceId) packetFor);
}
