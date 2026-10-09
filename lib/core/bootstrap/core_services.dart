import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/logging/debug_print_sink.dart';
import 'package:resqmesh/core/logging/file_log_sink.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// Services that need asynchronous set-up before the app can be used. The
/// splash screen is shown until [coreServicesProvider] has a value.
final class CoreServices {
  const CoreServices({required this.store, required this.supportDirectory});

  final KeyValueStore store;

  /// App-internal storage (`getApplicationSupportDirectory`): logs now,
  /// database and files later.
  final Directory supportDirectory;
}

/// The app-wide logger. Available immediately; the file sink is attached
/// once storage is ready.
final appLoggerProvider = Provider<AppLogger>((ref) {
  final logger = AppLogger(
    minLevel: kDebugMode ? LogLevel.debug : LogLevel.info,
    sinks: [if (kDebugMode) const DebugPrintSink()],
  );
  ref.onDispose(() => unawaited(logger.dispose()));
  return logger;
});

final coreServicesProvider = FutureProvider<CoreServices>((ref) async {
  final logger = ref.read(appLoggerProvider);
  final store = await PrefsKeyValueStore.open();
  final supportDirectory = await getApplicationSupportDirectory();
  // Start-up may be retried after a failure; attach the file sink only once.
  if (!logger.hasSink<FileLogSink>()) {
    logger.addSink(
      FileLogSink(Directory(p.join(supportDirectory.path, 'logs'))),
    );
  }
  await IdentityRepository(store).ensureDeviceId();
  logger.info(LogTag.app, 'Local storage ready');
  return CoreServices(store: store, supportDirectory: supportDirectory);
});

/// Only valid after start-up has finished (the router guarantees this for
/// every screen except the splash screen).
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => ref.watch(coreServicesProvider).requireValue.store,
);
