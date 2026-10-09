import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

import '../../support/fake_peer_links.dart';
import '../../support/fake_transfer_backend.dart';
import '../../support/test_database.dart';

const me = 'aaaaaaaa-0000-4000-8000-000000000001';
const rahim = 'bbbbbbbb-0000-4000-8000-000000000002';
const karim = 'cccccccc-0000-4000-8000-000000000003';
final sha = 'b' * 64;

/// This phone's transfer service on a real database and real files, with
/// the engine played by [FakeTransferBackend].
final class Harness {
  Harness._(
    this.db,
    this.dir,
    this.backend,
    this.links,
    this.service,
    this.free,
  );

  static Future<Harness> start({
    AppDatabase? database,
    Directory? directory,
    TransferPolicy policy = const TransferPolicy(
      retryBase: Duration(milliseconds: 20),
    ),
    int? freeBytes,
  }) async {
    final db = database ?? testDatabase();
    final dir =
        directory ?? await Directory.systemTemp.createTemp('resqmesh_svc');
    if (database == null) addTearDown(db.close);
    if (directory == null) addTearDown(() => dir.delete(recursive: true));
    final backend = FakeTransferBackend();
    final links = FakePeerLinks();
    final free = FreeSpace(freeBytes ?? 64 << 30);
    final service = TransferService(
      backend: backend,
      repository: DriftFileTransferRepository(db),
      store: FileStore(dir),
      links: links,
      self: () => SelfInfo(
        deviceId: me,
        name: 'Yusuf',
        nameClaimedAt: DateTime.utc(2026),
        announce: true,
      ),
      freeSpace: () async => free.bytes,
      logger: AppLogger(),
      policy: policy,
    );
    await service.start();
    return Harness._(db, dir, backend, links, service, free);
  }

  final AppDatabase db;
  final Directory dir;
  final FakeTransferBackend backend;
  final FakePeerLinks links;
  final TransferService service;
  final FreeSpace free;

  FileStore get store => FileStore(dir);

  Future<FileTransfer> transfer(String fileId) async =>
      (await service.find(fileId))!;

  /// A picked file in the cache, as the picker leaves it.
  Future<PickedFile> pick(String name, {int size = 1000}) async {
    final file = File(p.join(dir.path, 'cache', name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(size, 7));
    return PickedFile(path: file.path, name: name, size: size);
  }

  int _ids = 0;

  /// Prepares [name] for Rahim and waits until it is hashed.
  Future<String> prepare(String name, {String to = rahim}) async {
    final fileId = _id();
    final ready = service.ready.firstWhere((id) => id == fileId);
    await service.prepareOutgoing(
      await pick(name),
      fileId: fileId,
      messageId: _id(),
      peerId: to,
    );
    await ready;
    return fileId;
  }

  /// Prepared and confirmed by Rahim: ready to be scheduled.
  Future<String> queue(String name, {String to = rahim}) async {
    final id = await prepare(name, to: to);
    await service.onFileMessageAccepted(id);
    return id;
  }

  String _id() =>
      '0a4e6c1d-2b8f-4e57-a3c9-${(_ids++).toString().padLeft(12, '0')}';

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> ended(
    String fileId,
    TransferOutcome outcome, {
    int? bytes,
  }) async {
    backend.emit(TransferEnded(fileId, outcome, bytes: bytes));
    await settle();
  }

  /// Rahim's file MESSAGE arrived.
  Future<String> incoming({
    int size = 5000,
    String from = rahim,
    String? hash,
  }) async {
    final fileId = _id();
    expect(
      await service.registerIncoming(
        FileRef(
          fileId: fileId,
          name: '../photo.jpg',
          size: size,
          mimeType: 'image/jpeg',
          sha256: hash ?? sha,
        ),
        peerId: from,
        messageId: _id(),
      ),
      isTrue,
    );
    return fileId;
  }

  /// Rahim's engine offers [fileId]; returns this phone's answer.
  Future<OfferAnswer> offer(
    String fileId, {
    int size = 5000,
    String from = rahim,
    String? hash,
  }) async {
    backend.emit(
      OfferReceived(
        FileOfferPacket(
          PacketHeader.create(
            senderId: from,
            senderName: 'Rahim',
            receiverId: me,
          ),
          fileId: fileId,
          chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
          fileName: 'photo.jpg',
          fileSize: size,
          mimeType: 'image/jpeg',
          sha256: hash ?? sha,
        ),
        peerId: from,
      ),
    );
    await settle();
    return backend.answers.remove(fileId)!;
  }
}

final class FreeSpace {
  FreeSpace(this.bytes);

  int? bytes;
}

void main() {
  group('sending', () {
    test('a picked file is moved into sent/, hashed, then ready', () async {
      final h = await Harness.start();
      final picked = await h.pick('My Photo?.jpg', size: 4321);
      final fileId = h._id();
      final ready = h.service.ready.first;
      final prepared = await h.service.prepareOutgoing(
        picked,
        fileId: fileId,
        messageId: h._id(),
        peerId: rahim,
      );
      expect(prepared.status, TransferStatus.preparing);
      expect(prepared.name, 'My Photo_.jpg', reason: 'sanitised');
      expect(prepared.mimeType, 'image/jpeg');
      expect(prepared.size, 4321);
      expect(File(picked.path).existsSync(), isFalse, reason: 'moved');
      expect(h.store.file(FileStore.sentPath(fileId)).existsSync(), isTrue);

      expect(await ready, fileId);
      final transfer = await h.transfer(fileId);
      expect(transfer.status, TransferStatus.offered);
      expect(transfer.sha256, h.backend.hash);
      expect((await h.service.fileRef(fileId))!.sha256, h.backend.hash);
      expect(h.links.filePort, 28762, reason: 'file port announced');
    });

    test('a confirmed file is sent once the person is connected', () async {
      final h = await Harness.start();
      final id = await h.queue('report.pdf');
      await h.settle();
      expect(h.backend.uploads, isEmpty, reason: 'Rahim is not connected');
      expect((await h.transfer(id)).status, TransferStatus.queued);

      h.links.connect(rahim, address: '192.168.0.42');
      await h.settle();
      final upload = h.backend.uploads.single;
      expect(upload.fileId, id);
      expect(upload.address, '192.168.0.42');
      expect(upload.port, 28762);
      expect(upload.path, h.store.absolute(FileStore.sentPath(id)));
      expect((await h.transfer(id)).status, TransferStatus.inProgress);

      h.backend.emit(TransferStarted(id, offset: 0));
      h.backend.emit(TransferProgressed(id, bytes: 500));
      await h.settle();
      final progress = await h.service.watchProgress(id).first;
      expect(progress!.bytes, 500);
      expect(progress.total, 1000);

      await h.ended(id, const TransferCompleted());
      final done = await h.transfer(id);
      expect(done.status, TransferStatus.completed);
      expect(done.bytesTransferred, 1000);
      expect(await h.service.watchProgress(id).first, isNull);
    });

    test('a device that cannot receive files gets nothing sent', () async {
      final h = await Harness.start();
      h.links
        ..peerFilePort = null
        ..connect(rahim);
      await h.queue('a.txt');
      await h.settle();
      expect(h.backend.uploads, isEmpty);
    });

    test('at most three files are sent at a time', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final ids = [for (var i = 0; i < 5; i++) await h.queue('f$i.bin')];
      await h.settle();
      expect(h.backend.uploads.map((u) => u.fileId), ids.take(3));

      await h.ended(ids[1], const TransferCompleted());
      expect(h.backend.uploads.map((u) => u.fileId), [...ids.take(3), ids[3]]);
    });

    test('pause, then resume sends again', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final id = await h.queue('video.mp4');
      await h.settle();
      await h.service.pause(id);
      expect(h.backend.stops.single, (id, FileCancelReason.paused));
      await h.ended(id, const StoppedHere(FileCancelReason.paused), bytes: 400);
      final paused = await h.transfer(id);
      expect(paused.status, TransferStatus.paused);
      expect(paused.bytesTransferred, 400);

      await h.service.resume(id);
      await h.settle();
      expect(h.backend.uploads.where((u) => u.fileId == id), hasLength(2));
    });

    test(
      'a dropped transfer resumes by itself, then fails after 3 tries',
      () async {
        final h = await Harness.start(
          policy: const TransferPolicy(retryBase: Duration(milliseconds: 150)),
        );
        h.links.connect(rahim);
        final id = await h.queue('big.zip');
        await h.settle();
        for (var attempt = 1; attempt <= 3; attempt++) {
          h.backend.emit(
            TransferEnded(
              id,
              const TransferFailed(TransferFailure.connectionLost),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 40));
          final waiting = await h.transfer(id);
          expect(waiting.status, TransferStatus.queued);
          expect(waiting.attempts, attempt);
          expect(waiting.error, 'connectionLost');
          // After the backoff (150 ms × 2^(n-1)) it is sent again.
          final deadline = DateTime.now().add(const Duration(seconds: 3));
          while (h.backend.uploads.where((u) => u.fileId == id).length <
                  attempt + 1 &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          expect(
            h.backend.uploads.where((u) => u.fileId == id),
            hasLength(attempt + 1),
          );
        }
        await h.ended(id, const TransferFailed(TransferFailure.timedOut));
        final failed = await h.transfer(id);
        expect(failed.status, TransferStatus.failed);
        expect(failed.error, 'timedOut');

        await h.service.retry(id);
        await h.settle();
        final again = await h.transfer(id);
        expect(again.status, TransferStatus.inProgress);
        expect(again.attempts, 0);
      },
    );

    test('a damaged copy is resent once from zero, then fails', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final id = await h.queue('notes.txt');
      await h.settle();
      await h.ended(id, const StoppedByPeer(FileCancelReason.checksumMismatch));
      await h.settle();
      expect((await h.transfer(id)).status, TransferStatus.inProgress);
      expect(h.backend.uploads.where((u) => u.fileId == id), hasLength(2));

      await h.ended(id, const StoppedByPeer(FileCancelReason.checksumMismatch));
      final failed = await h.transfer(id);
      expect(failed.status, TransferStatus.failed);
      expect(failed.error, TransferErrors.checksumMismatch);
    });

    test(
      'rejections and cancels by the receiver are kept with the reason',
      () async {
        final h = await Harness.start();
        h.links.connect(rahim);
        final full = await h.queue('a.bin');
        final cancelled = await h.queue('b.bin');
        await h.settle();
        await h.ended(full, const TransferRejected(FileRejectReason.noSpace));
        await h.ended(
          cancelled,
          const StoppedByPeer(FileCancelReason.cancelled),
        );
        expect((await h.transfer(full)).status, TransferStatus.rejected);
        expect((await h.transfer(full)).error, 'noSpace');
        expect((await h.transfer(cancelled)).status, TransferStatus.cancelled);
        expect(
          (await h.transfer(cancelled)).error,
          TransferErrors.cancelledByPeer,
        );
      },
    );

    test('a file whose sent copy was deleted cannot be resent', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final id = await h.queue('gone.txt');
      await h.settle();
      await h.ended(id, const TransferRejected(FileRejectReason.noSpace));
      await h.store.delete(FileStore.sentPath(id));
      await h.service.retry(id);
      final failed = await h.transfer(id);
      expect(failed.status, TransferStatus.failed);
      expect(failed.error, TransferErrors.unavailable);
    });
  });

  group('receiving', () {
    test('an announced file is accepted into partial/ and received/', () async {
      final h = await Harness.start();
      final id = await h.incoming();
      final announced = await h.transfer(id);
      expect(announced.status, TransferStatus.offered);
      expect(announced.name, 'photo.jpg', reason: 'path stripped');

      final answer = await h.offer(id) as AcceptOffer;
      expect(answer.partPath, h.store.absolute(FileStore.partialPath(id)));
      expect(answer.finalPath, h.store.absolute(FileStore.receivedPath(id)));
      expect((await h.transfer(id)).status, TransferStatus.inProgress);

      await h.ended(id, const TransferCompleted());
      final done = await h.transfer(id);
      expect(done.status, TransferStatus.completed);
      expect(done.localPath, FileStore.receivedPath(id));
    });

    test('offers that do not match what was announced are refused', () async {
      final h = await Harness.start();
      final id = await h.incoming();
      expect(
        (await h.offer(id, hash: 'c' * 64) as RejectOffer).reason,
        FileRejectReason.invalid,
      );
      expect(
        (await h.offer(id, size: 1) as RejectOffer).reason,
        FileRejectReason.invalid,
      );
      expect(
        (await h.offer(id, from: karim) as RejectOffer).reason,
        FileRejectReason.invalid,
        reason: 'someone else offering Rahim\'s file',
      );
      expect(
        (await h.offer(h._id()) as RejectOffer).reason,
        FileRejectReason.invalid,
        reason: 'never announced',
      );
    });

    test('too large and not enough space are refused and recorded', () async {
      final h = await Harness.start(freeBytes: 300 << 20);
      final big = await h.incoming(size: 5 << 30);
      expect(
        (await h.offer(big, size: 5 << 30) as RejectOffer).reason,
        FileRejectReason.tooLarge,
      );
      // 150 MB would leave less than the 200 MB margin.
      final tight = await h.incoming(size: 150 << 20);
      expect(
        (await h.offer(tight, size: 150 << 20) as RejectOffer).reason,
        FileRejectReason.noSpace,
      );
      expect((await h.transfer(tight)).status, TransferStatus.rejected);
      expect((await h.transfer(tight)).error, 'noSpace');

      // After space is freed the sender's retry is accepted.
      h.free.bytes = 64 << 30;
      expect(await h.offer(tight, size: 150 << 20), isA<AcceptOffer>());
    });

    test(
      'the same content from the same person is not received twice',
      () async {
        final h = await Harness.start();
        final first = await h.incoming();
        await h.offer(first);
        await h.store
            .file(FileStore.receivedPath(first))
            .create(recursive: true);
        await h.ended(first, const TransferCompleted());

        final again = await h.incoming();
        expect(await h.offer(again), isA<AlreadyHaveFile>());
        final reused = await h.transfer(again);
        expect(reused.status, TransferStatus.completed);
        expect(reused.localPath, FileStore.receivedPath(first));

        // Deleting one keeps the shared copy for the other.
        await h.service.discard(again);
        expect(
          h.store.file(FileStore.receivedPath(first)).existsSync(),
          isTrue,
        );
      },
    );

    test('an offer for a completed file is answered at once; a cancelled '
        'one is declined', () async {
      final h = await Harness.start();
      final done = await h.incoming();
      await h.offer(done);
      await h.ended(done, const TransferCompleted());
      expect(await h.offer(done), isA<AlreadyHaveFile>());

      final cancelled = await h.incoming();
      await h.service.cancel(cancelled);
      expect(
        (await h.offer(cancelled) as RejectOffer).reason,
        FileRejectReason.declined,
      );
    });

    test('an interrupted download waits for the sender', () async {
      final h = await Harness.start();
      final id = await h.incoming();
      await h.offer(id);
      await h.ended(
        id,
        const TransferFailed(TransferFailure.connectionLost),
        bytes: 2000,
      );
      final paused = await h.transfer(id);
      expect(paused.status, TransferStatus.paused);
      expect(paused.bytesTransferred, 2000);

      await h.ended(id, const TransferFailed(TransferFailure.checksumMismatch));
      expect((await h.transfer(id)).status, TransferStatus.offered);
    });

    test('a file message reusing another file ID is refused', () async {
      final h = await Harness.start();
      final mine = await h.prepare('mine.txt');
      expect(
        await h.service.registerIncoming(
          FileRef(
            fileId: mine,
            name: 'x',
            size: 1,
            mimeType: 'text/plain',
            sha256: sha,
          ),
          peerId: rahim,
          messageId: h._id(),
        ),
        isFalse,
      );
    });
  });

  test('after a restart, nothing is left moving or half-prepared', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('resqmesh_restart');
    addTearDown(() => dir.delete(recursive: true));

    final before = await Harness.start(database: db, directory: dir);
    before.links.connect(rahim);
    final sending = await before.queue('up.bin');
    final receiving = await before.incoming();
    await before.offer(receiving);
    // The app is killed while a third file is still being hashed.
    before.backend.hashGate = Completer<void>();
    final preparing = before._id();
    await before.service.prepareOutgoing(
      await before.pick('slow.bin'),
      fileId: preparing,
      messageId: before._id(),
      peerId: rahim,
    );
    await before.settle();
    expect((await before.transfer(sending)).status, TransferStatus.inProgress);
    expect((await before.transfer(preparing)).status, TransferStatus.preparing);

    final after = await Harness.start(database: db, directory: dir);
    await after.settle();
    expect((await after.transfer(sending)).status, TransferStatus.queued);
    final paused = await after.transfer(receiving);
    expect(paused.status, TransferStatus.paused);
    expect(paused.error, TransferErrors.connectionLost);
    final prepared = await after.transfer(preparing);
    expect(prepared.status, TransferStatus.offered, reason: 'hashed again');
  });

  group('storage', () {
    test('clearing the cache keeps copies still needed', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final active = await h.queue('active.bin');
      final finished = await h.queue('done.bin');
      await h.settle();
      await h.ended(finished, const TransferCompleted());

      final freed = await h.service.clearCache();
      expect(freed, 1000);
      expect(h.store.file(FileStore.sentPath(active)).existsSync(), isTrue);
      expect(h.store.file(FileStore.sentPath(finished)).existsSync(), isFalse);
      final sent = await h.transfer(finished);
      expect(sent.status, TransferStatus.completed);
      expect(sent.localPath, isNull);
    });

    test('deleting received files marks them deleted', () async {
      final h = await Harness.start();
      final id = await h.incoming();
      await h.offer(id);
      await h.store.file(FileStore.receivedPath(id)).create(recursive: true);
      await h.ended(id, const TransferCompleted());

      expect(await h.service.deleteReceivedFiles(), 1);
      final deleted = await h.transfer(id);
      expect(deleted.isDeleted, isTrue);
      expect(h.store.file(FileStore.receivedPath(id)).existsSync(), isFalse);
    });

    test('stopping everything stops running transfers', () async {
      final h = await Harness.start();
      h.links.connect(rahim);
      final id = await h.queue('x.bin');
      await h.settle();
      await h.service.stopAll();
      expect(h.backend.stops.single, (id, FileCancelReason.cancelled));
    });
  });

  test('a network change rebinds the file port', () async {
    final h = await Harness.start();
    await h.service.networkChanged();
    expect(h.backend.resets, 1);
    expect(h.links.filePort, 28762);
    expect(clock.now(), isNotNull);
  });
}
