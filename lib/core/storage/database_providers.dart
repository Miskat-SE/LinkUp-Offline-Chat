import 'dart:async';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/storage_manager.dart';

/// The app's database, in app-internal storage. Queries run on a
/// background isolate, so the UI never waits on SQLite. Opened on first use.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final directory = ref
      .watch(coreServicesProvider)
      .requireValue
      .supportDirectory;
  final database = AppDatabase(
    driftDatabase(
      name: 'resqmesh',
      native: DriftNativeOptions(databaseDirectory: () async => directory),
    ),
  );
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final storageManagerProvider = Provider<StorageManager>(
  (ref) => StorageManager(ref.watch(appDatabaseProvider)),
);

/// How many messages are stored, for the Storage screen.
final messageCountProvider = StreamProvider<int>(
  (ref) => ref.watch(storageManagerProvider).watchMessageCount(),
);
