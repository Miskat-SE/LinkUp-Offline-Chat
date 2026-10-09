import 'package:shared_preferences/shared_preferences.dart';

/// Small settings and identity values. Reads are synchronous (served from a
/// cache loaded at start-up); writes complete when the value is persisted.
abstract interface class KeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

/// Every key the app stores. `SharedPreferencesWithCache` only loads keys
/// that are listed here.
abstract final class StoreKeys {
  static const deviceId = 'identity.deviceId';
  static const username = 'identity.username';
  static const nameClaimedAt = 'identity.nameClaimedAt';
  static const themeMode = 'settings.themeMode';
  static const connectionMethod = 'settings.connectionMethod';
  static const developerMode = 'settings.developerMode';

  static const all = {
    deviceId,
    username,
    nameClaimedAt,
    themeMode,
    connectionMethod,
    developerMode,
  };
}

/// [KeyValueStore] backed by Android `SharedPreferences`.
final class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore._(this._prefs);

  static Future<PrefsKeyValueStore> open() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: StoreKeys.all,
      ),
    );
    return PrefsKeyValueStore._(prefs);
  }

  final SharedPreferencesWithCache _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
