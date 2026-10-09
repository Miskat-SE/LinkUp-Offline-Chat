import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Watches the phone's local networks (Wi-Fi joined, own hotspot).
abstract interface class NetworkMonitor {
  NetworkSnapshot get current;

  /// Emits every change after [start].
  Stream<NetworkSnapshot> get changes;

  Future<void> start();

  Future<void> stop();

  /// Hold or release the Wi-Fi multicast lock while discovery runs.
  Future<void> setMulticastLock({required bool held});
}

/// [NetworkMonitor] backed by the Kotlin bridge (`LanBridge.kt`).
final class PlatformNetworkMonitor implements NetworkMonitor, LanFlutterApi {
  PlatformNetworkMonitor({LanHostApi? host}) : _host = host ?? LanHostApi();

  final LanHostApi _host;
  final StreamController<NetworkSnapshot> _changes =
      StreamController<NetworkSnapshot>.broadcast();
  NetworkSnapshot _current = NetworkSnapshot.none;

  @override
  NetworkSnapshot get current => _current;

  @override
  Stream<NetworkSnapshot> get changes => _changes.stream;

  @override
  Future<void> start() async {
    LanFlutterApi.setUp(this);
    await _host.startMonitoring();
    _update(await _host.currentSnapshot());
  }

  @override
  Future<void> stop() async {
    LanFlutterApi.setUp(null);
    try {
      await _host.stopMonitoring();
    } on PlatformException {
      // The engine may already be detached while the app shuts down.
    }
  }

  @override
  Future<void> setMulticastLock({required bool held}) =>
      held ? _host.acquireMulticastLock() : _host.releaseMulticastLock();

  @override
  void onLanChanged(LanSnapshot snapshot) => _update(snapshot);

  void _update(LanSnapshot raw) {
    final next = NetworkSnapshot(
      wifiConnected: raw.wifiConnected,
      boundToWifi: raw.boundToWifi,
      interfaces: [
        for (final i in raw.interfaces)
          if (_isIpv4(i.address) && i.prefixLength >= 8 && i.prefixLength <= 30)
            LanInterface(
              name: i.name,
              address: i.address,
              prefixLength: i.prefixLength,
              kind: switch (i.kind) {
                'wifi' => LanInterfaceKind.wifi,
                'hotspot' => LanInterfaceKind.hotspot,
                _ => LanInterfaceKind.other,
              },
            ),
      ],
    );
    if (next == _current) return;
    _current = next;
    _changes.add(next);
  }

  static final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

  static bool _isIpv4(String value) {
    final match = _ipv4.firstMatch(value);
    if (match == null) return false;
    for (var g = 1; g <= 4; g++) {
      if (int.parse(match.group(g)!) > 255) return false;
    }
    return true;
  }
}
