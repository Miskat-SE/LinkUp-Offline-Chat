import 'dart:async';
import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/file_store.dart';
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

/// Shared files in app-internal storage (PROJECT_PLAN.md §8.2).
final fileStoreProvider = Provider<FileStore>((ref) {
  final directory = ref
      .watch(coreServicesProvider)
      .requireValue
      .supportDirectory;
  return FileStore(Directory(p.join(directory.path, 'files')));
});

final storageManagerProvider = Provider<StorageManager>(
  (ref) => StorageManager(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStoreProvider),
  ),
);

/// What is stored, for the Storage screen; refreshed after each action.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) => ref.watch(storageManagerProvider).usage(),
);

/// How many messages are stored, for the Storage screen.
final messageCountProvider = StreamProvider<int>(
  (ref) => ref.watch(storageManagerProvider).watchMessageCount(),
);
