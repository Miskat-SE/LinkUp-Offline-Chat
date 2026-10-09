import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/engine/deferred_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/isolate_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer_repository.dart';

/// The transfer worker isolate (ADR-0010). Tests replace it.
final transferBackendProvider = Provider<TransferBackend>(
  (ref) => DeferredTransferBackend(IsolateTransferBackend.spawn()),
);

final fileTransferRepositoryProvider = Provider<FileTransferRepository>(
  (ref) => DriftFileTransferRepository(ref.watch(appDatabaseProvider)),
);

/// Runs file transfers for the life of the app.
final transferServiceProvider = Provider<TransferService>((ref) {
  final engine = ref.watch(discoveryEngineProvider);
  final files = ref.watch(fileActionsProvider);
  final service = TransferService(
    backend: ref.watch(transferBackendProvider),
    repository: ref.watch(fileTransferRepositoryProvider),
    store: ref.watch(fileStoreProvider),
    links: ref.watch(peerLinksProvider),
    self: () => engine.self,
    freeSpace: files.freeBytes,
    logger: ref.watch(appLoggerProvider),
  );
  // Follow the engine: a name set or changed, and network changes.
  NetworkSnapshot? lastNetwork;
  final subscription = engine.snapshots.listen((snapshot) {
    unawaited(service.identityChanged());
    if (lastNetwork != null && lastNetwork != snapshot.network) {
      unawaited(service.networkChanged());
    }
    lastNetwork = snapshot.network;
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(service.stop());
  });
  unawaited(service.start());
  return service;
});

/// One file's transfer record, live.
final fileTransferProvider = StreamProvider.family<FileTransfer?, String>(
  (ref, fileId) => ref.watch(fileTransferRepositoryProvider).watch(fileId),
);

/// Recent transfers, newest first (Activity screen).
final recentTransfersProvider = StreamProvider<List<FileTransfer>>(
  (ref) => ref.watch(fileTransferRepositoryProvider).watchRecent(),
);

/// Live progress while bytes are moving; null otherwise.
final transferProgressProvider =
    StreamProvider.family<TransferProgress?, String>(
      (ref, fileId) => ref.watch(transferServiceProvider).watchProgress(fileId),
    );
