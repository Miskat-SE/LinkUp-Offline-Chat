import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/bluetooth_controller.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

final bluetoothProvider = Provider<Bluetooth>((ref) => PlatformBluetooth());

/// Bluetooth is the chosen method (P14).
final usesBluetoothProvider = Provider<bool>(
  (ref) => ref.watch(connectionMethodProvider) == ConnectionMethod.bluetooth,
);

/// Finds phones over Bluetooth while it is the chosen method; null
/// otherwise.
final bluetoothControllerProvider = Provider<BluetoothController?>((ref) {
  if (!ref.watch(usesBluetoothProvider)) return null;
  final controller = BluetoothController(
    platform: ref.watch(bluetoothProvider),
    deviceId: () => ref.read(identityProvider).deviceId,
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(() => unawaited(controller.stop()));
  unawaited(() async {
    await controller.start();
    // Ask once, right after Bluetooth is chosen; later the card offers it.
    final store = ref.read(keyValueStoreProvider);
    if (controller.current.phase == BluetoothPhase.needsPermission &&
        store.getString(StoreKeys.bluetoothAsked) == null) {
      await store.setString(StoreKeys.bluetoothAsked, 'yes');
      await controller.requestPermission();
    }
  }());
  return controller;
});

/// Bluetooth state for the status card; null in other modes.
final bluetoothStatusProvider = StreamProvider<BluetoothStatus?>((ref) {
  final controller = ref.watch(bluetoothControllerProvider);
  return controller == null ? Stream.value(null) : controller.watch();
});
