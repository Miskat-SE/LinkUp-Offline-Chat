import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:resqmesh/core/storage/app_database.dart';

/// The real database schema on an in-memory SQLite database.
AppDatabase testDatabase() {
  // Tests open many databases side by side on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      // Widget tests fail on timers left after the app closes; drift
      // otherwise keeps a closed query cached until the next event loop.
      closeStreamsSynchronously: true,
    ),
  );
}
