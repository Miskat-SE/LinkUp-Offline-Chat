import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/app.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/app_info_provider.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

import 'fake_network_monitor.dart';
import 'fake_notifications.dart';
import 'fake_peer_links.dart';
import 'memory_datagram_network.dart';
import 'memory_key_value_store.dart';

/// Starts the real app with test stand-ins for the platform: [store] for
/// SharedPreferences, [network] for Wi-Fi, [lan] for UDP. This phone has
/// address [ip] on [lan].
Future<void> launchApp(
  WidgetTester tester,
  MemoryKeyValueStore store, {
  FakeNetworkMonitor? network,
  MemoryDatagramNetwork? lan,
  String ip = '192.168.0.10',
  FakePeerLinks? links,
  FakeNotifications? notifications,
  bool settle = true,
}) async {
  // A tall phone screen, so onboarding cards fit without scrolling.
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  // Reduce motion, as a user can in Android settings: looping illustrations
  // stand still and pumpAndSettle can finish.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    ProviderScope(
      // A fresh scope is a fresh app launch.
      key: UniqueKey(),
      overrides: [
        coreServicesProvider.overrideWith((ref) async {
          await IdentityRepository(store).ensureDeviceId();
          return CoreServices(
            store: store,
            supportDirectory: Directory.systemTemp,
          );
        }),
        appInfoProvider.overrideWith(
          (ref) async => AppInfo(versionName: '1.0.0', versionCode: 3),
        ),
        networkMonitorProvider.overrideWithValue(
          network ?? FakeNetworkMonitor(),
        ),
        datagramBinderProvider.overrideWithValue(
          (lan ?? MemoryDatagramNetwork()).binderFor(ip),
        ),
        serviceDiscoveryProvider.overrideWithValue(null),
        appNotificationsProvider.overrideWithValue(
          notifications ?? FakeNotifications(),
        ),
        peerLinksFactoryProvider.overrideWithValue(
          (self, logger) => links ?? FakePeerLinks(),
        ),
      ],
      child: const ResQMeshApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpFor(tester, const Duration(seconds: 1));
  }
}

/// Advances time in small steps, for screens with endless animations
/// (such as the "Searching…" spinner) where pumpAndSettle never finishes.
Future<void> pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Closes the app so discovery stops and its timers end.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await pumpFor(tester, const Duration(seconds: 1));
}
