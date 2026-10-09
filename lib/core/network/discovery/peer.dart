/// How a peer was heard from.
enum DiscoverySource { udp, nsd }

/// Another ResQMesh device seen on the local network.
final class Peer {
  const Peer({
    required this.deviceId,
    required this.name,
    required this.nameClaimedAt,
    required this.address,
    required this.tcpPort,
    required this.appVersion,
    required this.firstSeen,
    required this.lastSeen,
    required this.online,
    required this.sources,
  });

  final String deviceId;
  final String name;
  final DateTime nameClaimedAt;

  /// Last IPv4 address it was heard from.
  final String address;
  final int tcpPort;
  final String appVersion;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final bool online;
  final Set<DiscoverySource> sources;

  String get shortId => deviceId.substring(0, 4);

  Peer copyWith({
    String? name,
    DateTime? nameClaimedAt,
    String? address,
    int? tcpPort,
    String? appVersion,
    DateTime? lastSeen,
    bool? online,
    Set<DiscoverySource>? sources,
  }) => Peer(
    deviceId: deviceId,
    name: name ?? this.name,
    nameClaimedAt: nameClaimedAt ?? this.nameClaimedAt,
    address: address ?? this.address,
    tcpPort: tcpPort ?? this.tcpPort,
    appVersion: appVersion ?? this.appVersion,
    firstSeen: firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    online: online ?? this.online,
    sources: sources ?? this.sources,
  );

  /// Whether this device keeps [name] in a clash with a device that claimed
  /// the same name at [otherClaimedAt] with ID [otherId]: the earlier claim
  /// wins, ties go to the lower device ID (PROTOCOL.md §4.2).
  static bool winsNameClash({
    required DateTime claimedAt,
    required String deviceId,
    required DateTime otherClaimedAt,
    required String otherId,
  }) {
    if (claimedAt.isBefore(otherClaimedAt)) return true;
    if (claimedAt.isAfter(otherClaimedAt)) return false;
    return deviceId.compareTo(otherId) < 0;
  }
}
