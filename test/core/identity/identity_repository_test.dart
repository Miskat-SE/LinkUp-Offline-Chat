import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

import '../../support/memory_key_value_store.dart';

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late MemoryKeyValueStore store;
  late IdentityRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    repository = IdentityRepository(store);
  });

  test('creates a UUID v4 device ID on first launch', () async {
    await repository.ensureDeviceId();
    final identity = repository.read();
    expect(identity.deviceId, matches(_uuidPattern));
    expect(identity.hasName, isFalse);
  });

  test('keeps the same device ID on later launches', () async {
    await repository.ensureDeviceId();
    final first = repository.read().deviceId;
    // A new repository over the same storage is a new app launch.
    final relaunched = IdentityRepository(store);
    await relaunched.ensureDeviceId();
    expect(relaunched.read().deviceId, first);
  });

  test('read() before ensureDeviceId() is a programming error', () {
    expect(repository.read, throwsStateError);
  });

  test('stores the normalised name and the time it was claimed', () async {
    await repository.ensureDeviceId();
    final claimTime = DateTime.utc(2026, 10, 8, 19, 2, 44);
    final identity = await withClock(
      Clock.fixed(claimTime),
      () => repository.saveUsername('  Yusuf   Rahman '),
    );
    expect(identity.username, 'Yusuf Rahman');
    expect(identity.nameClaimedAt, claimTime);
    expect(store.getString(StoreKeys.username), 'Yusuf Rahman');
  });

  test('keeps the claim time when only case or spacing changes', () async {
    await repository.ensureDeviceId();
    final first = DateTime.utc(2026, 10, 8);
    await withClock(Clock.fixed(first), () => repository.saveUsername('Yusuf'));
    final identity = await withClock(
      Clock.fixed(first.add(const Duration(days: 1))),
      () => repository.saveUsername('yusuf'),
    );
    expect(identity.username, 'yusuf');
    expect(identity.nameClaimedAt, first);
  });

  test('a new name gets a new claim time', () async {
    await repository.ensureDeviceId();
    final first = DateTime.utc(2026, 10, 8);
    final later = first.add(const Duration(hours: 3));
    await withClock(Clock.fixed(first), () => repository.saveUsername('Yusuf'));
    final identity = await withClock(
      Clock.fixed(later),
      () => repository.saveUsername('Rahim'),
    );
    expect(identity.nameClaimedAt, later);
  });

  test('rejects invalid names without storing them', () async {
    await repository.ensureDeviceId();
    await expectLater(repository.saveUsername('T'), throwsArgumentError);
    expect(repository.read().hasName, isFalse);
  });
}
