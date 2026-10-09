import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/storage/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

/// Schema snapshots and migrations (PROJECT_PLAN.md §8.1).
///
/// When the schema changes: bump `AppDatabase.schemaVersion`, run
/// `dart run drift_dev make-migrations`, write the step in
/// `AppDatabase.migration`, and add a test below that migrates from the
/// previous version with real rows (see TESTING.md).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every schema version has a snapshot', () {
    final db = AppDatabase(DatabaseConnection(_unused));
    expect(
      GeneratedHelper.versions.last,
      db.schemaVersion,
      reason: 'run dart run drift_dev make-migrations',
    );
  });

  test('a new install creates exactly the latest schema', () async {
    final connection = await verifier.startAt(GeneratedHelper.versions.last);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, db.schemaVersion);
    await db.close();
  });

  test('v1 → v2 keeps every message and adds file sharing', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old
        .into(old.messages)
        .insert(
          v1.MessagesCompanion.insert(
            messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
            conversationId: 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61',
            peerName: 'Rahim',
            direction: 'out',
            body: 'Saved before the update',
            sentAt: 1,
            createdAt: 2,
            status: 'delivered',
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    final message = await db.select(db.messages).getSingle();
    expect(message.body, 'Saved before the update');
    expect(message.status, 'delivered');
    expect(message.kind, 'text');
    expect(message.fileId, isNull);
    expect(await db.select(db.files).get(), isEmpty);
    await db.close();
  });
}

/// For reading constants only; never opened.
final QueryExecutor _unused = LazyDatabase(
  () => throw StateError('not opened'),
);
