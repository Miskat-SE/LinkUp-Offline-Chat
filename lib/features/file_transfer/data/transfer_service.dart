import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:mime/mime.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/file_name_sanitizer.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer_repository.dart';

/// Limits and retry rules (PROJECT_PLAN.md §7.5, §7.6).
final class TransferPolicy {
  const TransferPolicy({
    this.maxFileSize = 4 << 30,
    this.freeSpaceMargin = 200 << 20,
    this.maxUploads = 3,
    this.autoRetries = 3,
    this.retryBase = const Duration(seconds: 2),
  });

  /// Larger offers are rejected as `tooLarge` (*Max file size*, 4 GiB).
  final int maxFileSize;

  /// Space that must stay free after receiving a file.
  final int freeSpaceMargin;

  /// Files sent at the same time.
  final int maxUploads;

  /// Automatic resumes after a dropped connection before Failed.
  final int autoRetries;
  final Duration retryBase;
}

/// A file the user picked, already copied into the app's cache.
final class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    this.size,
    this.mimeType,
  });

  final String path;
  final String name;
  final int? size;
  final String? mimeType;
}

/// Runs file transfers for the app (PROJECT_PLAN.md §7.5): prepares files,
/// answers offers, schedules uploads, resumes, and keeps the database and
/// live progress up to date. The bytes move in [TransferBackend].
///
/// The file MESSAGE itself goes through the chat's messaging service, which
/// calls [prepareOutgoing], [onFileMessageAccepted] and [registerIncoming].
final class TransferService {
  TransferService({
    required this._backend,
    required this._repository,
    required this._store,
    required this._links,
    required this._self,
    required this._freeSpace,
    required this._logger,
    this.policy = const TransferPolicy(),
  });

  final TransferBackend _backend;
  final FileTransferRepository _repository;
  final FileStore _store;
  final PeerLinks _links;
  final SelfInfo Function() _self;
  final Future<int?> Function() _freeSpace;
  final AppLogger _logger;
  final TransferPolicy policy;

  final StreamController<String> _ready = StreamController.broadcast();
  final StreamController<String> _progressChanged =
      StreamController.broadcast();
  final Map<String, _Tracker> _progress = {};
  final Set<String> _uploading = {};
  final Set<String> _receiving = {};
  final Map<String, DateTime> _notBefore = {};
  final Map<String, DateTime> _lastSaved = {};
  StreamSubscription<TransferEvent>? _events;
  StreamSubscription<LinksSnapshot>? _linkChanges;
  Set<String> _connected = {};
  Timer? _retryTimer;
  bool _backendStarted = false;
  Future<void> _queue = Future.value();

  /// Outgoing files whose preparation finished: their MESSAGE can go out.
  Stream<String> get ready => _ready.stream;

  Future<void> start() async {
    if (_events != null) return;
    _events = _backend.events.listen((e) => _serial(() => _onEvent(e)));
    _linkChanges = _links.snapshots.listen((s) => _serial(() => _onLinks(s)));
    await _serial(() async {
      await _store.ensureDirectories();
      await _recover();
    });
    await identityChanged();
  }

  Future<void> stop() async {
    unawaited(_events?.cancel());
    unawaited(_linkChanges?.cancel());
    _events = null;
    _linkChanges = null;
    _retryTimer?.cancel();
    await _backend.dispose();
    await _ready.close();
    await _progressChanged.close();
  }

  /// Name or onboarding changed: starts the file port once this device can
  /// announce itself, and keeps data HELLOs up to date.
  Future<void> identityChanged() async {
    final identity = _identity();
    if (identity == null) return;
    if (_backendStarted) {
      _backend.updateIdentity(identity);
      return;
    }
    _backendStarted = true;
    final port = await _backend.start(identity);
    _logger.info(LogTag.file, 'Listening for files', {'port': port});
    _links.setFilePort(port);
  }

  /// The network changed: running transfers drop (and resume later) and
  /// the file port is bound again.
  Future<void> networkChanged() async {
    if (!_backendStarted) return;
    final port = await _backend.reset();
    _links.setFilePort(port);
  }

  // ---------------------------------------------------------------- sending

  /// Moves a picked file into `sent/` under a new [fileId], records it as
  /// Preparing and starts hashing it. [ready] fires when it can be offered.
  Future<FileTransfer> prepareOutgoing(
    PickedFile picked, {
    required String fileId,
    required String messageId,
    required String peerId,
  }) => _serial(() async {
    final name = FileNameSanitizer.sanitize(picked.name);
    final mimeType =
        picked.mimeType ?? lookupMimeType(picked.name) ?? _octetStream;
    final relative = FileStore.sentPath(fileId);
    final target = _store.file(relative);
    await _moveInto(File(picked.path), target);
    final now = clock.now();
    final transfer = FileTransfer(
      fileId: fileId,
      messageId: messageId,
      peerId: peerId,
      direction: TransferDirection.outgoing,
      name: name,
      mimeType: mimeType,
      size: await target.length(),
      status: TransferStatus.preparing,
      localPath: relative,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insert(transfer);
    unawaited(_hash(transfer));
    return transfer;
  });

  Future<FileTransfer?> find(String fileId) => _repository.find(fileId);

  /// Another recipient for an already-picked file (multi-select and
  /// Everyone, P7.4): a new transfer that shares the stored copy and its
  /// hash, so the file is copied and hashed only once.
  Future<FileTransfer> shareOutgoing(
    String sourceFileId, {
    required String fileId,
    required String messageId,
    required String peerId,
  }) => _serial(() async {
    final source = await _repository.find(sourceFileId);
    if (source == null) throw StateError('unknown file $sourceFileId');
    final now = clock.now();
    final preparing = source.status == TransferStatus.preparing;
    final usable = preparing || source.sha256 != null;
    final transfer = FileTransfer(
      fileId: fileId,
      messageId: messageId,
      peerId: peerId,
      direction: TransferDirection.outgoing,
      name: source.name,
      mimeType: source.mimeType,
      size: source.size,
      status: preparing
          ? TransferStatus.preparing
          : (usable ? TransferStatus.offered : TransferStatus.failed),
      sha256: source.sha256,
      localPath: source.localPath,
      error: usable ? null : TransferErrors.unavailable,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.insert(transfer);
    return transfer;
  });

  /// The file description for its MESSAGE, once hashed.
  Future<FileRef?> fileRef(String fileId) async {
    final transfer = await _repository.find(fileId);
    final sha256 = transfer?.sha256;
    if (transfer == null || sha256 == null) return null;
    return FileRef(
      fileId: fileId,
      name: transfer.name,
      size: transfer.size,
      mimeType: transfer.mimeType,
      sha256: sha256,
    );
  }

  /// The receiver stored the file MESSAGE: the data may follow.
  Future<void> onFileMessageAccepted(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null || transfer.status != TransferStatus.offered) return;
    await _repository.update(fileId, status: TransferStatus.queued);
    await _schedule();
  });

  /// Pauses a file being sent; it continues from where it stopped.
  Future<void> pause(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null || !transfer.isOutgoing) return;
    if (_uploading.contains(fileId)) {
      _backend.stop(fileId, FileCancelReason.paused);
    } else if (transfer.status == TransferStatus.queued) {
      await _repository.update(fileId, status: TransferStatus.paused);
    }
  });

  Future<void> resume(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null ||
        !transfer.isOutgoing ||
        transfer.status != TransferStatus.paused) {
      return;
    }
    await _requeue(transfer);
  });

  /// Sends a failed or rejected file again from the start of what the
  /// receiver has.
  Future<void> retry(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null || !transfer.isOutgoing) return;
    if (transfer.status != TransferStatus.failed &&
        transfer.status != TransferStatus.rejected) {
      return;
    }
    await _requeue(transfer);
  });

  Future<void> _requeue(FileTransfer transfer) async {
    final path = transfer.localPath;
    if (path == null || !_store.file(path).existsSync()) {
      await _repository.update(
        transfer.fileId,
        status: TransferStatus.failed,
        error: TransferErrors.unavailable,
      );
      return;
    }
    _notBefore.remove(transfer.fileId);
    await _repository.update(
      transfer.fileId,
      status: TransferStatus.queued,
      attempts: 0,
      clearError: true,
    );
    await _schedule();
  }

  /// Stops a transfer for good, in either direction.
  Future<void> cancel(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null || transfer.status.isFinished) return;
    if (_uploading.contains(fileId) || _receiving.contains(fileId)) {
      _backend.stop(fileId, FileCancelReason.cancelled);
      return;
    }
    await _repository.update(fileId, status: TransferStatus.cancelled);
    if (!transfer.isOutgoing) {
      await _store.delete(FileStore.partialPath(fileId));
    }
  });

  /// The message was deleted: stops the transfer and removes its files.
  Future<void> discard(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    if (transfer == null) return;
    if (_uploading.contains(fileId) || _receiving.contains(fileId)) {
      _backend.stop(fileId, FileCancelReason.cancelled);
    }
    await _repository.delete(fileId);
    _progress.remove(fileId);
    await _deleteCopy(transfer.localPath);
    await _store.delete(FileStore.partialPath(fileId));
  });

  /// Removes a received file's copy; its card then shows "File deleted".
  Future<void> deleteCopy(String fileId) => _serial(() async {
    final transfer = await _repository.find(fileId);
    final path = transfer?.localPath;
    if (transfer == null || path == null) return;
    await _repository.update(fileId, clearLocalPath: true);
    await _deleteCopy(path);
  });

  Future<void> _deleteCopy(String? path) async {
    if (path == null) return;
    // Duplicates share one copy; keep it while anyone uses it.
    if (await _repository.countUsing(path) == 0) await _store.delete(path);
  }

  // ---------------------------------------------------------------- storage

  /// Stops every running transfer, before Storage deletes everything.
  Future<void> stopAll() => _serial(() async {
    for (final id in {..._uploading, ..._receiving}) {
      _backend.stop(id, FileCancelReason.cancelled);
    }
    _uploading.clear();
    _receiving.clear();
    _notBefore.clear();
    for (final id in _progress.keys.toList()) {
      _untrack(id);
    }
  });

  /// Storage → Clear cached files: copies of sent files and unfinished
  /// downloads that nothing is using now, and every thumbnail. Returns the
  /// bytes freed.
  Future<int> clearCache() => _serial(() async {
    final before = await _cacheBytes();
    final keep = <String>{};
    for (final transfer in await _repository.withStatus({
      TransferStatus.preparing,
      TransferStatus.offered,
      TransferStatus.queued,
      TransferStatus.inProgress,
      TransferStatus.paused,
    }, direction: TransferDirection.outgoing)) {
      if (transfer.localPath case final path?) keep.add(path);
    }
    for (final id in _receiving) {
      keep.add(FileStore.partialPath(id));
    }
    await _store.clear(FileStore.sentDir, keep: keep);
    await _store.clear(FileStore.partialDir, keep: keep);
    await _store.clear(FileStore.thumbsDir);
    // Sent copies that are gone can't be resent: say so on their cards.
    for (final transfer in await _repository.withStatus({
      TransferStatus.completed,
      TransferStatus.failed,
      TransferStatus.cancelled,
      TransferStatus.rejected,
    }, direction: TransferDirection.outgoing)) {
      final path = transfer.localPath;
      if (path != null && !keep.contains(path)) {
        await _repository.update(transfer.fileId, clearLocalPath: true);
      }
    }
    return before - await _cacheBytes();
  });

  Future<int> _cacheBytes() async {
    var bytes = 0;
    for (final dir in [
      FileStore.sentDir,
      FileStore.partialDir,
      FileStore.thumbsDir,
    ]) {
      bytes += (await _store.usage(dir)).bytes;
    }
    return bytes;
  }

  /// Storage → Delete received files: the messages stay and their cards
  /// show "File deleted". Returns how many files were deleted.
  Future<int> deleteReceivedFiles() => _serial(() async {
    final received = await _repository.withStatus({
      TransferStatus.completed,
    }, direction: TransferDirection.incoming);
    for (final transfer in received) {
      if (transfer.localPath != null) {
        await _repository.update(transfer.fileId, clearLocalPath: true);
      }
    }
    await _store.clear(FileStore.thumbsDir);
    return _store.clear(FileStore.receivedDir);
  });

  // -------------------------------------------------------------- receiving

  /// A file MESSAGE arrived: records the file so its data is expected.
  /// Returns false if the file ID belongs to something else.
  Future<bool> registerIncoming(
    FileRef file, {
    required String peerId,
    required String messageId,
  }) => _serial(() async {
    final existing = await _repository.find(file.fileId);
    if (existing != null) {
      return !existing.isOutgoing &&
          existing.peerId == peerId &&
          existing.messageId == messageId;
    }
    final now = clock.now();
    await _repository.insert(
      FileTransfer(
        fileId: file.fileId,
        messageId: messageId,
        peerId: peerId,
        direction: TransferDirection.incoming,
        name: FileNameSanitizer.sanitize(file.name),
        mimeType: file.mimeType,
        size: file.size,
        sha256: file.sha256,
        status: TransferStatus.offered,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return true;
  });

  Future<OfferAnswer> _decide(OfferReceived event) async {
    final offer = event.offer;
    final transfer = await _repository.find(offer.fileId);
    if (transfer == null ||
        transfer.isOutgoing ||
        transfer.peerId != event.peerId ||
        transfer.size != offer.fileSize ||
        transfer.sha256 != offer.sha256) {
      _logger.warning(LogTag.file, 'Unexpected file offer', {
        'file': _short(offer.fileId),
      });
      return const RejectOffer(FileRejectReason.invalid);
    }
    switch (transfer.status) {
      case TransferStatus.completed:
        return transfer.localPath == null
            ? const RejectOffer(FileRejectReason.declined)
            : const AlreadyHaveFile();
      case TransferStatus.cancelled:
        return const RejectOffer(FileRejectReason.declined);
      default:
        break;
    }
    if (offer.fileSize > policy.maxFileSize) {
      return _reject(transfer, FileRejectReason.tooLarge);
    }
    // The same content from the same person is reused, not sent again.
    final same = await _repository.findReceivedContent(
      peerId: event.peerId,
      sha256: offer.sha256,
      size: offer.fileSize,
    );
    final samePath = same?.localPath;
    if (same != null &&
        samePath != null &&
        same.fileId != offer.fileId &&
        _store.file(samePath).existsSync()) {
      await _repository.update(
        offer.fileId,
        status: TransferStatus.completed,
        bytesTransferred: offer.fileSize,
        localPath: samePath,
        clearError: true,
      );
      _logger.info(LogTag.file, 'Duplicate file reused', {
        'file': _short(offer.fileId),
      });
      return const AlreadyHaveFile();
    }
    final part = _store.file(FileStore.partialPath(offer.fileId));
    final have = part.existsSync() ? await part.length() : 0;
    final free = await _freeSpace();
    if (free != null && offer.fileSize - have > free - policy.freeSpaceMargin) {
      return _reject(transfer, FileRejectReason.noSpace);
    }
    _receiving.add(offer.fileId);
    await _repository.update(
      offer.fileId,
      status: TransferStatus.inProgress,
      bytesTransferred: have,
      clearError: true,
    );
    return AcceptOffer(
      partPath: part.path,
      finalPath: _store.absolute(FileStore.receivedPath(offer.fileId)),
    );
  }

  Future<OfferAnswer> _reject(
    FileTransfer transfer,
    FileRejectReason reason,
  ) async {
    _logger.info(LogTag.file, 'File refused', {
      'file': _short(transfer.fileId),
      'reason': reason.name,
    });
    await _repository.update(
      transfer.fileId,
      status: TransferStatus.rejected,
      error: reason.name,
    );
    return RejectOffer(reason);
  }

  // --------------------------------------------------------------- progress

  /// Live progress of a running transfer; null when nothing is moving.
  Stream<TransferProgress?> watchProgress(String fileId) async* {
    yield _progress[fileId]?.snapshot;
    yield* _progressChanged.stream
        .where((id) => id == fileId)
        .map((_) => _progress[fileId]?.snapshot);
  }

  void _track(String fileId, int bytes, int total) {
    final tracker = _progress.putIfAbsent(fileId, () => _Tracker(total));
    tracker.add(clock.now(), bytes);
    if (!_progressChanged.isClosed) _progressChanged.add(fileId);
  }

  void _untrack(String fileId) {
    if (_progress.remove(fileId) != null && !_progressChanged.isClosed) {
      _progressChanged.add(fileId);
    }
    _lastSaved.remove(fileId);
  }

  // ----------------------------------------------------------------- events

  Future<void> _onEvent(TransferEvent event) async {
    switch (event) {
      case OfferReceived():
        _backend.answer(event.fileId, await _decide(event));
      case TransferStarted(:final fileId, :final offset):
        final transfer = await _repository.find(fileId);
        if (transfer == null) return;
        _progress.remove(fileId);
        _track(fileId, offset, transfer.size);
        await _repository.update(
          fileId,
          status: TransferStatus.inProgress,
          bytesTransferred: offset,
        );
      case TransferProgressed(:final fileId, :final bytes):
        final tracker = _progress[fileId];
        if (tracker == null) return;
        _track(fileId, bytes, tracker.total);
        final now = clock.now();
        final saved = _lastSaved[fileId];
        if (saved == null ||
            now.difference(saved) >= const Duration(seconds: 1)) {
          _lastSaved[fileId] = now;
          await _repository.update(fileId, bytesTransferred: bytes);
        }
      case TransferEnded():
        _untrack(event.fileId);
        final transfer = await _repository.find(event.fileId);
        if (transfer == null) return;
        if (transfer.isOutgoing) {
          _uploading.remove(event.fileId);
          await _uploadEnded(transfer, event);
        } else {
          _receiving.remove(event.fileId);
          await _downloadEnded(transfer, event);
        }
        await _schedule();
    }
  }

  Future<void> _uploadEnded(FileTransfer transfer, TransferEnded event) async {
    final id = transfer.fileId;
    switch (event.outcome) {
      case TransferCompleted():
        _logger.info(LogTag.file, 'File sent', {'file': _short(id)});
        await _repository.update(
          id,
          status: TransferStatus.completed,
          bytesTransferred: transfer.size,
          attempts: 0,
          clearError: true,
        );
      case TransferRejected(:final reason):
        await _repository.update(
          id,
          status: TransferStatus.rejected,
          error: reason.name,
        );
      case StoppedHere(:final reason):
        await _repository.update(
          id,
          status: reason == FileCancelReason.paused
              ? TransferStatus.paused
              : TransferStatus.cancelled,
          bytesTransferred: event.bytes,
        );
      case StoppedByPeer(reason: FileCancelReason.cancelled):
        await _repository.update(
          id,
          status: TransferStatus.cancelled,
          error: TransferErrors.cancelledByPeer,
        );
      case StoppedByPeer(reason: FileCancelReason.paused):
        await _repository.update(
          id,
          status: TransferStatus.paused,
          error: TransferErrors.pausedByPeer,
          bytesTransferred: event.bytes,
        );
      case StoppedByPeer(reason: FileCancelReason.checksumMismatch) ||
          TransferFailed(failure: TransferFailure.checksumMismatch):
        // The receiver deleted the bad copy: one more try from zero.
        final again = transfer.error != TransferErrors.checksumMismatch;
        _logger.warning(LogTag.file, 'Checksum mismatch', {
          'file': _short(id),
          'retry': again,
        });
        await _repository.update(
          id,
          status: again ? TransferStatus.queued : TransferStatus.failed,
          error: TransferErrors.checksumMismatch,
          bytesTransferred: 0,
        );
      case TransferFailed(failure: TransferFailure.unavailable):
        await _repository.update(
          id,
          status: TransferStatus.failed,
          error: TransferErrors.unavailable,
        );
      case TransferFailed(:final failure, :final detail):
        await _retryLater(transfer, failure.name, detail, event.bytes);
      case StoppedByPeer():
        await _retryLater(
          transfer,
          TransferErrors.connectionLost,
          'stopped by the receiver',
          event.bytes,
        );
    }
  }

  /// A dropped transfer resumes by itself a few times, with backoff.
  Future<void> _retryLater(
    FileTransfer transfer,
    String error,
    String? detail,
    int? bytes,
  ) async {
    final attempts = transfer.attempts + 1;
    final giveUp = attempts > policy.autoRetries;
    _logger.warning(LogTag.file, 'Transfer interrupted', {
      'file': _short(transfer.fileId),
      'error': error,
      'detail': ?detail,
      'attempt': attempts,
    });
    if (!giveUp) {
      _notBefore[transfer.fileId] = clock.now().add(
        policy.retryBase * pow(2, attempts - 1).toInt(),
      );
    }
    await _repository.update(
      transfer.fileId,
      status: giveUp ? TransferStatus.failed : TransferStatus.queued,
      error: error,
      attempts: attempts,
      bytesTransferred: bytes,
    );
  }

  Future<void> _downloadEnded(
    FileTransfer transfer,
    TransferEnded event,
  ) async {
    final id = transfer.fileId;
    switch (event.outcome) {
      case TransferCompleted():
        if (transfer.status == TransferStatus.completed) return; // duplicate
        _logger.info(LogTag.file, 'File received', {'file': _short(id)});
        await _repository.update(
          id,
          status: TransferStatus.completed,
          bytesTransferred: transfer.size,
          localPath: transfer.localPath ?? FileStore.receivedPath(id),
          clearError: true,
        );
      case TransferRejected():
        break; // Recorded when it was decided.
      case StoppedHere(reason: FileCancelReason.cancelled):
        await _repository.update(id, status: TransferStatus.cancelled);
      case StoppedByPeer(reason: FileCancelReason.cancelled):
        await _repository.update(
          id,
          status: TransferStatus.cancelled,
          error: TransferErrors.cancelledByPeer,
        );
      case StoppedByPeer(reason: FileCancelReason.paused):
        await _repository.update(
          id,
          status: TransferStatus.paused,
          error: TransferErrors.pausedByPeer,
          bytesTransferred: event.bytes,
        );
      case TransferFailed(failure: TransferFailure.checksumMismatch):
        // The bad copy is gone; the sender tries once more.
        await _repository.update(
          id,
          status: TransferStatus.offered,
          error: TransferErrors.checksumMismatch,
          bytesTransferred: 0,
        );
      case TransferFailed(:final failure):
        await _repository.update(
          id,
          status: TransferStatus.paused,
          error: failure.name,
          bytesTransferred: event.bytes,
        );
      case StoppedHere() || StoppedByPeer():
        await _repository.update(
          id,
          status: TransferStatus.paused,
          error: TransferErrors.connectionLost,
          bytesTransferred: event.bytes,
        );
    }
  }

  // ------------------------------------------------------------- scheduling

  Future<void> _onLinks(LinksSnapshot snapshot) async {
    final now = snapshot.links.keys.toSet();
    final joined = now.difference(_connected);
    _connected = now;
    if (joined.isNotEmpty) {
      // Someone came back: their files get a fresh set of attempts.
      for (final transfer in await _repository.withStatus({
        TransferStatus.queued,
      }, direction: TransferDirection.outgoing)) {
        if (!joined.contains(transfer.peerId)) continue;
        _notBefore.remove(transfer.fileId);
        if (transfer.attempts > 0) {
          await _repository.update(transfer.fileId, attempts: 0);
        }
      }
    }
    await _schedule();
  }

  Future<void> _schedule() async {
    final links = _links.current.links;
    final now = clock.now();
    for (final transfer in await _repository.withStatus({
      TransferStatus.queued,
    }, direction: TransferDirection.outgoing)) {
      if (_uploading.length >= policy.maxUploads) break;
      final id = transfer.fileId;
      if (_uploading.contains(id)) continue;
      final link = links[transfer.peerId];
      final filePort = link?.filePort;
      if (link == null || filePort == null) continue;
      final notBefore = _notBefore[id];
      if (notBefore != null && now.isBefore(notBefore)) continue;
      final path = transfer.localPath;
      final sha256 = transfer.sha256;
      if (path == null || sha256 == null || !_store.file(path).existsSync()) {
        await _repository.update(
          id,
          status: TransferStatus.failed,
          error: TransferErrors.unavailable,
        );
        continue;
      }
      _notBefore.remove(id);
      _uploading.add(id);
      await _repository.update(id, status: TransferStatus.inProgress);
      _backend.upload(
        UploadRequest(
          fileId: id,
          chatMessageId: transfer.messageId,
          peerId: transfer.peerId,
          address: link.address,
          port: filePort,
          path: _store.absolute(path),
          fileName: transfer.name,
          fileSize: transfer.size,
          mimeType: transfer.mimeType,
          sha256: sha256,
        ),
      );
    }
    _armRetryTimer();
  }

  void _armRetryTimer() {
    _retryTimer?.cancel();
    if (_notBefore.isEmpty) return;
    final next = _notBefore.values.reduce((a, b) => a.isBefore(b) ? a : b);
    var wait = next.difference(clock.now());
    if (wait.isNegative) wait = Duration.zero;
    _retryTimer = Timer(wait, () => unawaited(_serial(_schedule)));
  }

  // ---------------------------------------------------------------- startup

  /// After a restart nothing is moving: sends wait to be scheduled again,
  /// receives wait for the sender, and unfinished hashing starts over.
  Future<void> _recover() async {
    final hashing = <String?>{};
    for (final transfer in await _repository.withStatus({
      TransferStatus.inProgress,
      TransferStatus.preparing,
    })) {
      switch ((transfer.status, transfer.isOutgoing)) {
        case (TransferStatus.preparing, _):
          // Shared copies are hashed once.
          if (hashing.add(transfer.localPath)) unawaited(_hash(transfer));
        case (_, true):
          await _repository.update(
            transfer.fileId,
            status: TransferStatus.queued,
          );
        case (_, false):
          await _repository.update(
            transfer.fileId,
            status: TransferStatus.paused,
            error: TransferErrors.connectionLost,
          );
      }
    }
  }

  Future<void> _hash(FileTransfer transfer) async {
    final path = transfer.localPath;
    String? sha256;
    if (path != null && _store.file(path).existsSync()) {
      try {
        sha256 = await _backend.hashFile(_store.absolute(path));
      } on Object catch (e) {
        _logger.error(LogTag.file, 'Hashing failed', {'error': e.runtimeType});
      }
    }
    await _serial(() async {
      // Every transfer sharing this copy (fan-out) is ready at once.
      final waiting = [
        for (final t in await _repository.withStatus({
          TransferStatus.preparing,
        }, direction: TransferDirection.outgoing))
          if (t.fileId == transfer.fileId ||
              (path != null && t.localPath == path))
            t,
      ];
      for (final t in waiting) {
        if (sha256 == null) {
          await _repository.update(
            t.fileId,
            status: TransferStatus.failed,
            error: TransferErrors.unavailable,
          );
          continue;
        }
        await _repository.update(
          t.fileId,
          status: TransferStatus.offered,
          sha256: sha256,
        );
        if (!_ready.isClosed) _ready.add(t.fileId);
      }
    });
  }

  // ---------------------------------------------------------------- helpers

  TransferIdentity? _identity() {
    final self = _self();
    final name = self.name;
    final claimedAt = self.nameClaimedAt;
    if (!self.canAnnounce || name == null || claimedAt == null) return null;
    return TransferIdentity(
      deviceId: self.deviceId,
      name: name,
      nameClaimedAt: claimedAt,
      appVersion: self.appVersion,
    );
  }

  /// The picker's cache copy is moved, not copied (same partition,
  /// ADR-0014); copying is only a fallback.
  static Future<void> _moveInto(File source, File target) async {
    await target.parent.create(recursive: true);
    try {
      await source.rename(target.path);
    } on FileSystemException {
      await source.copy(target.path);
      try {
        await source.delete();
      } on FileSystemException {
        // The picker clears its cache itself.
      }
    }
  }

  static const _octetStream = 'application/octet-stream';

  static String _short(String id) => id.substring(0, 4);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then(
      (_) {},
      onError: (Object e, StackTrace s) {
        _logger.error(LogTag.file, 'Transfer step failed', {
          'error': e.runtimeType,
        });
      },
    );
    return result;
  }
}

/// Speed as a moving average over the last 2 s.
final class _Tracker {
  _Tracker(this.total);

  final int total;
  final List<(DateTime, int)> _samples = [];

  void add(DateTime time, int bytes) {
    _samples.add((time, bytes));
    final cutoff = time.subtract(const Duration(seconds: 2));
    while (_samples.length > 2 && _samples.first.$1.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
  }

  TransferProgress get snapshot {
    final (lastTime, lastBytes) = _samples.last;
    final (firstTime, firstBytes) = _samples.first;
    final elapsed = lastTime.difference(firstTime).inMicroseconds;
    return TransferProgress(
      bytes: lastBytes,
      total: total,
      bytesPerSecond: elapsed < 250000
          ? null
          : (lastBytes - firstBytes) * 1e6 / elapsed,
    );
  }
}
