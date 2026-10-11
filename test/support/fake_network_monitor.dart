import 'dart:async';

import 'package:resqmesh/core/network/network_monitor.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';

/// A [NetworkMonitor] whose network the test sets.
final class FakeNetworkMonitor implements NetworkMonitor {
  FakeNetworkMonitor([this._current = NetworkSnapshot.none]);

  /// A phone that joined Wi-Fi with [ip] on a /24.
  factory FakeNetworkMonitor.onWifi(String ip) =>
      FakeNetworkMonitor(wifiSnapshot(ip));

  static NetworkSnapshot wifiSnapshot(String ip) => NetworkSnapshot(
    wifiConnected: true,
    boundToWifi: true,
    interfaces: [
      LanInterface(
        name: 'wlan0',
        address: ip,
        prefixLength: 24,
        kind: LanInterfaceKind.wifi,
      ),
    ],
  );

  NetworkSnapshot _current;
  final StreamController<NetworkSnapshot> _changes =
      StreamController<NetworkSnapshot>.broadcast();
  bool multicastLockHeld = false;
  bool boundToWifi = true;

  @override
  NetworkSnapshot get current => _current;

  @override
  Stream<NetworkSnapshot> get changes => _changes.stream;

  void set(NetworkSnapshot snapshot) {
    _current = snapshot;
    _changes.add(snapshot);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setMulticastLock({required bool held}) async {
    multicastLockHeld = held;
  }

  @override
  Future<void> setBindToWifi({required bool bind}) async {
    boundToWifi = bind;
  }
}
