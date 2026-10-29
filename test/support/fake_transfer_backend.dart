import 'dart:async';

import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';

/// Records what the app asks the transfer engine to do; tests play the
/// engine's side with [emit].
final class FakeTransferBackend implements TransferBackend {
  final StreamController<TransferEvent> _events =
      StreamController<TransferEvent>.broadcast();

  final List<UploadRequest> uploads = [];
  final Map<String, OfferAnswer> answers = {};
  final List<(String, FileCancelReason)> stops = [];
  TransferIdentity? identity;
  int resets = 0;

  /// The file port start() and reset() report; null when it can't open.
  int? port = 28762;

  /// SHA-256 returned for any file.
  String hash = 'a' * 64;

  /// While set, hashing waits for it (a slow or interrupted hash).
  Completer<void>? hashGate;

  void emit(TransferEvent event) => _events.add(event);

  @override
  Stream<TransferEvent> get events => _events.stream;

  @override
  Future<int?> start(TransferIdentity self) async {
    identity = self;
    return port;
  }

  @override
  Future<int?> reset() async {
    resets++;
    return port;
  }

  @override
  void updateIdentity(TransferIdentity self) => identity = self;

  @override
  void upload(UploadRequest request) => uploads.add(request);

  @override
  void answer(String fileId, OfferAnswer answer) => answers[fileId] = answer;

  @override
  void stop(String fileId, FileCancelReason reason) =>
      stops.add((fileId, reason));

  /// How many files were hashed.
  int hashes = 0;

  @override
  Future<String> hashFile(String path) async {
    hashes++;
    await hashGate?.future;
    return hash;
  }

  @override
  Future<void> dispose() => _events.close();
}
