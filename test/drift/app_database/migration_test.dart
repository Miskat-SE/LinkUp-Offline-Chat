import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/storage/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

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

  test('from v1, every message is kept through to the latest schema', () async {
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
    await verifier.migrateAndValidate(db, db.schemaVersion);
    final message = await db.select(db.messages).getSingle();
    expect(message.body, 'Saved before the update');
    expect(message.status, 'delivered');
    expect(message.kind, 'text');
    expect(message.fileId, isNull);
    expect(await db.select(db.files).get(), isEmpty);
    await db.close();
  });

  test('from v2, messages and files are kept and Everyone is added', () async {
    final schema = await verifier.schemaAt(2);
    final old = v2.DatabaseAtV2(schema.newConnection());
    await old
        .into(old.messages)
        .insert(
          v2.MessagesCompanion.insert(
            messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
            conversationId: 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61',
            peerName: 'Rahim',
            direction: 'in',
            body: '',
            sentAt: 1,
            createdAt: 2,
            status: 'received',
            kind: const Value('file'),
            fileId: const Value('0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80'),
          ),
        );
    await old
        .into(old.files)
        .insert(
          v2.FilesCompanion.insert(
            fileId: '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80',
            messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
            peerId: 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61',
            direction: 'in',
            name: 'photo.jpg',
            mimeType: 'image/jpeg',
            size: 10,
            status: 'completed',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    final message = await db.select(db.messages).getSingle();
    expect(message.kind, 'file');
    expect(message.audience, 'direct');
    expect(message.senderId, isNull);
    expect((await db.select(db.files).getSingle()).name, 'photo.jpg');
    expect(await db.select(db.messageRecipients).get(), isEmpty);
    await db.close();
  });

  test('from v3, messages and recipients are kept; none deleted', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await old
        .into(old.messages)
        .insert(
          v3.MessagesCompanion.insert(
            messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
            conversationId: 'everyone',
            peerName: 'Everyone',
            direction: 'out',
            body: 'Meeting in hall B',
            sentAt: 1,
            createdAt: 2,
            status: 'sent',
            audience: const Value('everyone'),
          ),
        );
    await old
        .into(old.messageRecipients)
        .insert(
          v3.MessageRecipientsCompanion.insert(
            messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
            recipientId: 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61',
            recipientName: 'Rahim',
            status: 'read',
            updatedAt: 3,
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, db.schemaVersion);
    final message = await db.select(db.messages).getSingle();
    expect(message.body, 'Meeting in hall B');
    expect(message.deletedAt, isNull);
    expect(await db.select(db.messageRecipients).get(), hasLength(1));
    await db.close();
  });
}

/// For reading constants only; never opened.
final QueryExecutor _unused = LazyDatabase(
  () => throw StateError('not opened'),
);
