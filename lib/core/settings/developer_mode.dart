import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// Whether the hidden developer screen is unlocked (spec §34). Always on in
/// debug builds; in release builds the user taps the version 7 times.
final developerModeProvider = NotifierProvider<DeveloperModeController, bool>(
  DeveloperModeController.new,
);

final class DeveloperModeController extends Notifier<bool> {
  @override
  bool build() =>
      kDebugMode ||
      ref.watch(keyValueStoreProvider).getString(StoreKeys.developerMode) ==
          'on';

  Future<void> unlock() async {
    state = true;
    await ref
        .read(keyValueStoreProvider)
        .setString(StoreKeys.developerMode, 'on');
  }
}
