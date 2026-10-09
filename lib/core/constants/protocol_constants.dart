/// Numbers from PROTOCOL.md that both sides of a connection must agree on.
abstract final class ProtocolConstants {
  static const int version = 1;

  /// UDP discovery port (PROTOCOL.md §1). Unassigned by IANA and below
  /// Android's ephemeral range.
  static const int udpPort = 28760;

  /// Preferred TCP listening port (P3).
  static const int tcpPort = 28761;

  /// NSD / mDNS service type.
  static const String serviceType = '_resqmesh._tcp';

  /// Every UDP datagram starts with these four bytes: "RQM1".
  static const List<int> datagramMagic = [0x52, 0x51, 0x4D, 0x31];

  static const int maxDatagramBytes = 1400;
  static const int maxControlFrameBytes = 64 * 1024;
  static const int maxFileChunkBytes = 256 * 1024;
}

/// Discovery timing (PROJECT_PLAN.md §6.3).
abstract final class DiscoveryTiming {
  static const Duration helloInterval = Duration(seconds: 5);
  static const Duration helloJitter = Duration(seconds: 1);
  static const Duration offlineAfter = Duration(seconds: 20);
  static const Duration isolationHintAfter = Duration(seconds: 30);
  static const Duration nameCheckWait = Duration(seconds: 3);
  static const Duration maxResponseDelay = Duration(milliseconds: 300);
  static const Duration expiryCheck = Duration(seconds: 2);
}
