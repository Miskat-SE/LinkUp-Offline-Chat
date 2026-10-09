import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

import 'fake_network_monitor.dart';
import 'memory_datagram_network.dart';
import 'memory_key_value_store.dart';
import 'test_app.dart';

/// Device ID of the second test phone ("Rahim").
const otherPhoneId = 'bbbbbbbb-0000-4000-8000-000000000002';

/// A second phone on the same test LAN, running the real engine.
Future<DiscoveryEngine> startOtherPhone(
  MemoryDatagramNetwork lan, {
  required String name,
  DateTime? claimedAt,
}) async {
  const ip = '192.168.0.11';
  final engine = DiscoveryEngine(
    network: FakeNetworkMonitor.onWifi(ip),
    bindUdp: lan.binderFor(ip),
    logger: AppLogger(),
    self: SelfInfo(
      deviceId: otherPhoneId,
      name: name,
      nameClaimedAt: claimedAt ?? DateTime.utc(2026),
      announce: true,
      appVersion: '1.0.0+3',
    ),
  );
  await engine.start();
  return engine;
}

/// Stops the other phone and the app, so no discovery timers outlive the
/// test.
Future<void> finish(WidgetTester tester, DiscoveryEngine other) async {
  await other.stop();
  await closeApp(tester);
}

/// A phone that finished onboarding. [stayReachableOffered] is true by
/// default so the one-time offer doesn't push Home's list down in tests.
MemoryKeyValueStore onboarded({
  String name = 'Yusuf',
  DateTime? claimedAt,
  bool stayReachableOffered = true,
}) => MemoryKeyValueStore({
  StoreKeys.username: name,
  StoreKeys.nameClaimedAt: (claimedAt ?? DateTime.utc(2026, 9))
      .toIso8601String(),
  StoreKeys.connectionMethod: 'wifiRouter',
  if (stayReachableOffered) StoreKeys.stayReachableOffered: 'yes',
});
