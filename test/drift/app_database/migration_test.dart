import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/storage/app_database.dart';

import 'generated/schema.dart';

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
}

/// For reading constants only; never opened.
final QueryExecutor _unused = LazyDatabase(
  () => throw StateError('not opened'),
);
