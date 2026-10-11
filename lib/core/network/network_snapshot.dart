/// What kind of local network an interface is on.
enum LanInterfaceKind {
  /// This phone joined a Wi-Fi network.
  wifi,

  /// This phone is the hotspot (access point) others join.
  hotspot,

  /// A Wi-Fi Direct group, as owner or member (ADR-0023).
  wifiDirect,

  /// Anything else local, e.g. Ethernet.
  other,
}

/// One IPv4 address on a local interface.
final class LanInterface {
  const LanInterface({
    required this.name,
    required this.address,
    required this.prefixLength,
    required this.kind,
  });

  final String name;

  /// Dotted IPv4 address.
  final String address;
  final int prefixLength;
  final LanInterfaceKind kind;

  /// Subnet-directed broadcast address, e.g. `192.168.0.255` for a /24.
  String get broadcast {
    final host = (1 << (32 - prefixLength)) - 1;
    return _format(_parse(address) | host);
  }

  /// Network address with prefix, e.g. `192.168.0.0/24`.
  String get subnet {
    final mask = prefixLength == 0 ? 0 : (0xFFFFFFFF << (32 - prefixLength));
    return '${_format(_parse(address) & mask & 0xFFFFFFFF)}/$prefixLength';
  }

  static int _parse(String ip) => ip
      .split('.')
      .map(int.parse)
      .fold(0, (value, part) => (value << 8) | part);

  static String _format(int value) =>
      [for (var shift = 24; shift >= 0; shift -= 8) (value >> shift) & 0xFF]
          .join('.');

  @override
  bool operator ==(Object other) =>
      other is LanInterface &&
      other.name == name &&
      other.address == address &&
      other.prefixLength == prefixLength &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(name, address, prefixLength, kind);

  @override
  String toString() => '$name $address/$prefixLength (${kind.name})';
}

/// The phone's local networks at one moment, as reported by the bridge.
final class NetworkSnapshot {
  const NetworkSnapshot({
    required this.wifiConnected,
    required this.boundToWifi,
    required this.interfaces,
  });

  static const none = NetworkSnapshot(
    wifiConnected: false,
    boundToWifi: false,
    interfaces: [],
  );

  final bool wifiConnected;
  final bool boundToWifi;
  final List<LanInterface> interfaces;

  /// A local network exists: joined Wi-Fi, or this phone's own hotspot.
  /// Internet access is never part of this decision (spec §16).
  bool get hasLan => interfaces.isNotEmpty;

  /// This phone is sharing a hotspot.
  bool get isHotspotHost =>
      interfaces.any((i) => i.kind == LanInterfaceKind.hotspot);

  /// This phone is in a Wi-Fi Direct group.
  bool get inWifiDirectGroup =>
      interfaces.any((i) => i.kind == LanInterfaceKind.wifiDirect);

  /// Where discovery broadcasts go: each subnet's broadcast address, plus
  /// the limited broadcast address.
  List<String> get broadcastTargets =>
      {for (final i in interfaces) i.broadcast, '255.255.255.255'}.toList();

  @override
  bool operator ==(Object other) =>
      other is NetworkSnapshot &&
      other.wifiConnected == wifiConnected &&
      other.boundToWifi == boundToWifi &&
      _sameInterfaces(other.interfaces, interfaces);

  @override
  int get hashCode =>
      Object.hash(wifiConnected, boundToWifi, Object.hashAll(interfaces));

  static bool _sameInterfaces(List<LanInterface> a, List<LanInterface> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
