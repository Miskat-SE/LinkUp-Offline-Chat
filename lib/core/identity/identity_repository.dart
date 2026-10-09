import 'package:clock/clock.dart';
import 'package:resqmesh/core/identity/local_identity.dart';
import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:uuid/uuid.dart';

/// Persists the device ID and username (spec §4, §5).
final class IdentityRepository {
  IdentityRepository(this._store, {this._uuid = const Uuid()});

  final KeyValueStore _store;
  final Uuid _uuid;

  /// Creates and stores a device ID on first launch. Safe to call every launch.
  Future<void> ensureDeviceId() async {
    if (_store.getString(StoreKeys.deviceId) != null) return;
    await _store.setString(StoreKeys.deviceId, _uuid.v4());
  }

  /// The stored identity. [ensureDeviceId] must have completed first.
  LocalIdentity read() {
    final deviceId = _store.getString(StoreKeys.deviceId);
    if (deviceId == null) {
      throw StateError('Device ID missing: call ensureDeviceId() at start-up');
    }
    final claimedAt = _store.getString(StoreKeys.nameClaimedAt);
    return LocalIdentity(
      deviceId: deviceId,
      username: _store.getString(StoreKeys.username),
      nameClaimedAt: claimedAt == null ? null : DateTime.tryParse(claimedAt),
    );
  }

  /// Stores [name] after validating it. The claim time is updated only when
  /// the name actually changes, ignoring case and spacing, so re-saving the
  /// same name doesn't lose a name clash (PROJECT_PLAN.md §6.4).
  Future<LocalIdentity> saveUsername(String name) async {
    final validation = Username.validate(name);
    if (validation is! ValidUsername) {
      throw ArgumentError.value(name, 'name', 'is not a valid username');
    }
    final current = read();
    final unchanged =
        current.username != null &&
        Username.same(current.username!, validation.name);
    await _store.setString(StoreKeys.username, validation.name);
    if (!unchanged || current.nameClaimedAt == null) {
      await _store.setString(
        StoreKeys.nameClaimedAt,
        clock.now().toUtc().toIso8601String(),
      );
    }
    return read();
  }
}
