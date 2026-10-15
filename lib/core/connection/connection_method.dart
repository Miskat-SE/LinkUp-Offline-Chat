/// How this phone reaches other phones (PROJECT_PLAN.md §2.1, D20).
enum ConnectionMethod {
  /// Everyone joins the same Wi-Fi router; works with its internet off.
  wifiRouter(available: true),

  /// One phone shares a hotspot and the others join it. Same LAN code as
  /// [wifiRouter].
  hotspot(available: true),

  /// Phone to phone over Android Wi-Fi Direct: the phones form a group by
  /// themselves, and the LAN code runs over it (P13, ADR-0023).
  wifiDirect(available: true),

  /// Bluetooth LE to find phones and L2CAP channels to carry the usual
  /// connections, for when Wi-Fi is off entirely (P14).
  bluetooth(available: true);

  const ConnectionMethod({required this.available});

  /// Whether this build can use the method. Unavailable methods are shown
  /// as "Coming soon" and can't be chosen.
  final bool available;

  static ConnectionMethod? fromName(String? name) {
    for (final method in values) {
      if (method.name == name) return method;
    }
    return null;
  }
}
