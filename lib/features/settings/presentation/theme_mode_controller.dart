import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// Light, dark or follow the system (Settings → Theme).
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // The splash screen is themed before storage is ready.
    final store = ref.watch(coreServicesProvider).value?.store;
    final stored = store?.getString(StoreKeys.themeMode);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(keyValueStoreProvider)
        .setString(StoreKeys.themeMode, mode.name);
  }
}
