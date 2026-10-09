import 'dart:async';

import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';

/// A [TransferBackend] that is still starting (the worker isolate spawns
/// asynchronously). Calls wait for it; events flow once it is up.
final class DeferredTransferBackend implements TransferBackend {
  DeferredTransferBackend(this._backend) {
    unawaited(
      _backend.then((backend) => _forward = backend.events.listen(_events.add)),
    );
  }

  final Future<TransferBackend> _backend;
  final StreamController<TransferEvent> _events =
      StreamController<TransferEvent>.broadcast();
  StreamSubscription<TransferEvent>? _forward;

  @override
  Stream<TransferEvent> get events => _events.stream;

  @override
  Future<int?> start(TransferIdentity self) async =>
      (await _backend).start(self);

  @override
  Future<int?> reset() async => (await _backend).reset();

  @override
  void updateIdentity(TransferIdentity self) =>
      unawaited(_backend.then((b) => b.updateIdentity(self)));

  @override
  void upload(UploadRequest request) =>
      unawaited(_backend.then((b) => b.upload(request)));

  @override
  void answer(String fileId, OfferAnswer answer) =>
      unawaited(_backend.then((b) => b.answer(fileId, answer)));

  @override
  void stop(String fileId, FileCancelReason reason) =>
      unawaited(_backend.then((b) => b.stop(fileId, reason)));

  @override
  Future<String> hashFile(String path) async => (await _backend).hashFile(path);

  @override
  Future<void> dispose() async {
    final backend = await _backend;
    await _forward?.cancel();
    await backend.dispose();
    await _events.close();
  }
}
