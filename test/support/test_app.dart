import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/app.dart';
import 'package:resqmesh/app/restartable_app.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/wifi_direct_providers.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/app_info_provider.dart';
import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/features/file_transfer/data/file_picker_service.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';

import 'fake_background_service.dart';
import 'fake_file_actions.dart';
import 'fake_file_picker.dart';
import 'fake_network_monitor.dart';
import 'fake_notifications.dart';
import 'fake_peer_links.dart';
import 'fake_transfer_backend.dart';
import 'fake_wifi_direct.dart';
import 'memory_datagram_network.dart';
import 'memory_key_value_store.dart';
import 'test_database.dart';

/// Starts the real app with test stand-ins for the platform: [store] for
/// SharedPreferences, [network] for Wi-Fi, [lan] for UDP, and an in-memory
/// SQLite [database]. This phone has address [ip] on [lan]. Pass the same
/// [store] and [database] again to simulate a restart.
Future<void> launchApp(
  WidgetTester tester,
  MemoryKeyValueStore store, {
  FakeNetworkMonitor? network,
  MemoryDatagramNetwork? lan,
  String ip = '192.168.0.10',
  FakePeerLinks? links,
  FakeNotifications? notifications,
  AppDatabase? database,
  FakeTransferBackend? transfers,
  FakeFileActions? fileActions,
  FakeFilePicker? picker,
  FakeBackgroundService? background,
  FakeWifiDirect? wifiDirect,
  Directory? supportDirectory,
  bool settle = true,
}) async {
  final db = database ?? testDatabase();
  if (database == null) addTearDown(db.close);
  // Each launch gets its own app storage unless a restart is simulated.
  final support =
      supportDirectory ?? Directory.systemTemp.createTempSync('resqmesh_app');
  if (supportDirectory == null) {
    addTearDown(() => support.deleteSync(recursive: true));
  }
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
    // A fresh scope is a fresh app launch; RestartableApp starts it over
    // after Clear all local data, as in the app.
    RestartableApp(
      key: UniqueKey(),
      builder: (key) => ProviderScope(
        key: key,
        overrides: [
          coreServicesProvider.overrideWith((ref) async {
            await IdentityRepository(store).ensureDeviceId();
            return CoreServices(store: store, supportDirectory: support);
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
          // Not closed with the app, so a test can launch it again.
          appDatabaseProvider.overrideWithValue(db),
          transferBackendProvider.overrideWithValue(
            transfers ?? FakeTransferBackend(),
          ),
          fileActionsProvider.overrideWithValue(
            fileActions ?? FakeFileActions(),
          ),
          filePickerProvider.overrideWithValue(picker ?? FakeFilePicker()),
          wifiDirectProvider.overrideWithValue(wifiDirect ?? FakeWifiDirect()),
          backgroundServiceProvider.overrideWithValue(
            background ?? FakeBackgroundService(),
          ),
          appNotificationsProvider.overrideWithValue(
            notifications ?? FakeNotifications(),
          ),
          peerLinksFactoryProvider.overrideWithValue(
            (self, logger) => links ?? FakePeerLinks(),
          ),
        ],
        child: const ResQMeshApp(),
      ),
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
