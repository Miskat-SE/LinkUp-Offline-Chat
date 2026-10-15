import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/connection/wifi_direct_controller.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

final wifiDirectProvider = Provider<WifiDirect>((ref) => PlatformWifiDirect());

/// Runs Wi-Fi Direct while it is the chosen method; null otherwise. In
/// Wi-Fi Direct mode the app is not bound to the joined Wi-Fi (ADR-0023).
final wifiDirectControllerProvider = Provider<WifiDirectController?>((ref) {
  final monitor = ref.watch(networkMonitorProvider);
  if (ref.watch(connectionMethodProvider) != ConnectionMethod.wifiDirect) {
    unawaited(monitor.setBindToWifi(bind: true));
    return null;
  }
  unawaited(monitor.setBindToWifi(bind: false));
  final controller = WifiDirectController(
    platform: ref.watch(wifiDirectProvider),
    self: () {
      final identity = ref.read(identityProvider);
      return (deviceId: identity.deviceId, name: identity.username ?? '');
    },
    logger: ref.watch(appLoggerProvider),
  );
  ref
    ..listen(identityProvider, (_, _) => unawaited(controller.nameChanged()))
    ..onDispose(() => unawaited(controller.stop()));
  unawaited(() async {
    await controller.start();
    // Ask once, right after Wi-Fi Direct is chosen; later the status card
    // offers the button.
    final store = ref.read(keyValueStoreProvider);
    if (controller.current.phase == WifiDirectPhase.needsPermission &&
        store.getString(StoreKeys.wifiDirectAsked) == null) {
      await store.setString(StoreKeys.wifiDirectAsked, 'yes');
      await controller.requestPermission();
    }
  }());
  return controller;
});

/// Wi-Fi Direct state for the status card; null in other modes.
final wifiDirectStatusProvider = StreamProvider<WifiDirectStatus?>((ref) {
  final controller = ref.watch(wifiDirectControllerProvider);
  return controller == null ? Stream.value(null) : controller.watch();
});
