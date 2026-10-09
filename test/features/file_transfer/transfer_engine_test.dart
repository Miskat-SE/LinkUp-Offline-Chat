import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/file_transfer/data/engine/isolate_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';
const idC = 'cccccccc-0000-4000-8000-000000000003';

const fast = TransferTiming(
  helloTimeout: Duration(seconds: 2),
  offerTimeout: Duration(seconds: 2),
  answerTimeout: Duration(seconds: 5),
  idleTimeout: Duration(seconds: 5),
  progressInterval: Duration.zero,
);

TransferIdentity identity(String id, String name) => TransferIdentity(
  deviceId: id,
  name: name,
  nameClaimedAt: DateTime.utc(2026),
  appVersion: 'test',
);

/// Two engines on loopback: Yusuf sends, Rahim receives.
final class Pair {
  Pair._(this.dir, this.sender, this.receiver, this.receiverPort);

  static Future<Pair> start({
    int chunkSize = 64 * 1024,
    TransferBackend? receiverBackend,
  }) async {
    final dir = await Directory.systemTemp.createTemp('resqmesh_transfer');
    addTearDown(() => dir.delete(recursive: true));
    final sender = TransferEngine(
      preferredPort: 0,
      timing: fast,
      chunkSize: chunkSize,
      flushEvery: chunkSize * 4,
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final receiver =
        receiverBackend ??
        TransferEngine(
          preferredPort: 0,
          timing: fast,
          bindAddress: InternetAddress.loopbackIPv4,
        );
    await sender.start(identity(idA, 'Yusuf'));
    final port = await receiver.start(identity(idB, 'Rahim'));
    final pair = Pair._(dir, sender, receiver, port!);
    receiver.events.listen(pair._onReceiverEvent);
    sender.events.listen(pair.senderEvents.add);
    addTearDown(() async {
      await sender.dispose();
      await receiver.dispose();
    });
    return pair;
  }

  final Directory dir;
  final TransferEngine sender;
  final TransferBackend receiver;
  final int receiverPort;

  final List<TransferEvent> senderEvents = [];
  final List<TransferEvent> receiverEvents = [];

  /// How Rahim answers offers; accepts by default.
  OfferAnswer Function(OfferReceived offer) decide = (offer) =>
      const AcceptOffer(partPath: '', finalPath: '');

  String partPath(String fileId) => p.join(dir.path, 'partial', '$fileId.part');
  String finalPath(String fileId) => p.join(dir.path, 'received', fileId);

  void _onReceiverEvent(TransferEvent event) {
    receiverEvents.add(event);
    if (event is OfferReceived) {
      final answer = decide(event);
      receiver.answer(
        event.fileId,
        answer is AcceptOffer
            ? AcceptOffer(
                partPath: partPath(event.fileId),
                finalPath: finalPath(event.fileId),
              )
            : answer,
      );
    }
  }

  Future<File> makeFile(String name, int size, {int seed = 1}) async {
    final file = File(p.join(dir.path, 'source', name));
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    final random = Random(seed);
    var left = size;
    while (left > 0) {
      final n = min(left, 1 << 20);
      sink.add(
        Uint8List.fromList(List.generate(n, (_) => random.nextInt(256))),
      );
      left -= n;
    }
    await sink.close();
    return file;
  }

  int _ids = 0;

  /// Sends [file]; [sha256Override] simulates corruption.
  Future<String> send(
    File file, {
    String? sha256Override,
    String to = idB,
    int? size,
  }) async {
    final fileId =
        '0a4e6c1d-2b8f-4e57-a3c9-${(_ids++).toString().padLeft(12, '0')}';
    sender.upload(
      UploadRequest(
        fileId: fileId,
        chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
        peerId: to,
        address: '127.0.0.1',
        port: receiverPort,
        path: file.path,
        fileName: p.basename(file.path),
        fileSize: size ?? await file.length(),
        mimeType: 'application/octet-stream',
        sha256: sha256Override ?? await sender.hashFile(file.path),
      ),
    );
    return fileId;
  }

  Future<TransferEnded> senderEnd(String fileId) =>
      _ended(senderEvents, fileId);

  Future<TransferEnded> receiverEnd(String fileId) =>
      _ended(receiverEvents, fileId);

  Future<TransferEnded> _ended(
    List<TransferEvent> events,
    String fileId,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      for (final event in events) {
        if (event is TransferEnded && event.fileId == fileId) {
          events.remove(event);
          return event;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('transfer $fileId did not end');
  }

  /// Waits until Rahim has written at least [bytes] of [fileId].
  Future<void> receivedAtLeast(String fileId, int bytes) async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      if (receiverEvents.any(
        (e) =>
            e is TransferProgressed && e.fileId == fileId && e.bytes >= bytes,
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    fail('$fileId never reached $bytes bytes');
  }
}

Future<String> hashOf(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

void main() {
  test('a file arrives whole, verified and renamed into place', () async {
    final pair = await Pair.start();
    final source = await pair.makeFile('photo.jpg', 3 * 1024 * 1024 + 17);
    final id = await pair.send(source);

    expect((await pair.senderEnd(id)).outcome, isA<TransferCompleted>());
    final received = await pair.receiverEnd(id);
    expect(received.outcome, isA<TransferCompleted>());
    expect(received.bytes, await source.length());

    final offer = pair.receiverEvents.whereType<OfferReceived>().single;
    expect(offer.peerId, idA);
    expect(offer.offer.fileName, 'photo.jpg');
    expect(await hashOf(File(pair.finalPath(id))), await hashOf(source));
    expect(File(pair.partPath(id)).existsSync(), isFalse);
  });

  test('an empty file is sent without any data frames', () async {
    final pair = await Pair.start();
    final source = await pair.makeFile('empty.txt', 0);
    final id = await pair.send(source);
    expect((await pair.senderEnd(id)).outcome, isA<TransferCompleted>());
    expect((await pair.receiverEnd(id)).outcome, isA<TransferCompleted>());
    expect(File(pair.finalPath(id)).lengthSync(), 0);
  });

  test('a rejected offer ends on both sides with the reason', () async {
    final pair = await Pair.start();
    pair.decide = (_) => const RejectOffer(FileRejectReason.noSpace);
    final id = await pair.send(await pair.makeFile('big.zip', 1000));
    final ended = await pair.senderEnd(id);
    expect(
      ended.outcome,
      isA<TransferRejected>().having(
        (o) => o.reason,
        'reason',
        FileRejectReason.noSpace,
      ),
    );
    expect(File(pair.partPath(id)).existsSync(), isFalse);
  });

  test('a file the receiver already has completes without data', () async {
    final pair = await Pair.start();
    pair.decide = (_) => const AlreadyHaveFile();
    final source = await pair.makeFile('again.pdf', 5 * 1024 * 1024);
    final id = await pair.send(source);
    final ended = await pair.senderEnd(id);
    expect(ended.outcome, isA<TransferCompleted>());
    expect(
      pair.senderEvents.whereType<TransferProgressed>().where(
        (e) => e.fileId == id,
      ),
      isEmpty,
    );
  });

  test('the sender cancels: the receiver deletes the partial file', () async {
    final pair = await Pair.start(chunkSize: 16 * 1024);
    final id = await pair.send(await pair.makeFile('movie.mp4', 30 << 20));
    await pair.receivedAtLeast(id, 1 << 20);
    pair.sender.stop(id, FileCancelReason.cancelled);

    expect(
      (await pair.senderEnd(id)).outcome,
      isA<StoppedHere>().having(
        (o) => o.reason,
        'reason',
        FileCancelReason.cancelled,
      ),
    );
    expect(
      (await pair.receiverEnd(id)).outcome,
      isA<StoppedByPeer>().having(
        (o) => o.reason,
        'reason',
        FileCancelReason.cancelled,
      ),
    );
    expect(File(pair.partPath(id)).existsSync(), isFalse);
    expect(File(pair.finalPath(id)).existsSync(), isFalse);
  });

  test('pause keeps the partial file and resume continues from it', () async {
    final pair = await Pair.start(chunkSize: 16 * 1024);
    final source = await pair.makeFile('archive.zip', 30 << 20, seed: 7);
    final id = await pair.send(source);
    await pair.receivedAtLeast(id, 2 << 20);
    pair.sender.stop(id, FileCancelReason.paused);
    expect((await pair.senderEnd(id)).outcome, isA<StoppedHere>());
    final paused = await pair.receiverEnd(id);
    expect(
      paused.outcome,
      isA<StoppedByPeer>().having(
        (o) => o.reason,
        'reason',
        FileCancelReason.paused,
      ),
    );
    final kept = File(pair.partPath(id)).lengthSync();
    expect(kept, greaterThan(0));
    expect(kept, lessThan(30 << 20));

    // Resume: same file ID, the receiver offers to continue at its size.
    pair.sender.upload(
      UploadRequest(
        fileId: id,
        chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
        peerId: idB,
        address: '127.0.0.1',
        port: pair.receiverPort,
        path: source.path,
        fileName: 'archive.zip',
        fileSize: 30 << 20,
        mimeType: 'application/zip',
        sha256: await hashOf(source),
      ),
    );
    expect((await pair.senderEnd(id)).outcome, isA<TransferCompleted>());
    expect((await pair.receiverEnd(id)).outcome, isA<TransferCompleted>());
    final started = pair.senderEvents.whereType<TransferStarted>().last;
    expect(started.offset, kept, reason: 'continued from the partial file');
    expect(await hashOf(File(pair.finalPath(id))), await hashOf(source));
  });

  test('the receiver cancels: the sender is told', () async {
    final pair = await Pair.start(chunkSize: 16 * 1024);
    final id = await pair.send(await pair.makeFile('song.mp3', 30 << 20));
    await pair.receivedAtLeast(id, 1 << 20);
    pair.receiver.stop(id, FileCancelReason.cancelled);
    expect(
      (await pair.senderEnd(id)).outcome,
      isA<StoppedByPeer>().having(
        (o) => o.reason,
        'reason',
        FileCancelReason.cancelled,
      ),
    );
    expect((await pair.receiverEnd(id)).outcome, isA<StoppedHere>());
    expect(File(pair.partPath(id)).existsSync(), isFalse);
  });

  test('corrupted data is detected, deleted and reported', () async {
    final pair = await Pair.start();
    final source = await pair.makeFile('notes.txt', 200 * 1024);
    final wrong = sha256.convert([1, 2, 3]).toString();
    final id = await pair.send(source, sha256Override: wrong);
    expect(
      (await pair.receiverEnd(id)).outcome,
      isA<TransferFailed>().having(
        (o) => o.failure,
        'failure',
        TransferFailure.checksumMismatch,
      ),
    );
    expect(
      (await pair.senderEnd(id)).outcome,
      isA<StoppedByPeer>().having(
        (o) => o.reason,
        'reason',
        FileCancelReason.checksumMismatch,
      ),
    );
    expect(File(pair.partPath(id)).existsSync(), isFalse);
    expect(File(pair.finalPath(id)).existsSync(), isFalse);
  });

  test('a dropped connection keeps the partial file for resuming', () async {
    final pair = await Pair.start(chunkSize: 16 * 1024);
    final id = await pair.send(await pair.makeFile('video.mp4', 30 << 20));
    await pair.receivedAtLeast(id, 1 << 20);
    await pair.receiver.reset(); // the network went away
    expect(
      (await pair.receiverEnd(id)).outcome,
      isA<TransferFailed>().having(
        (o) => o.failure,
        'failure',
        TransferFailure.connectionLost,
      ),
    );
    expect(
      (await pair.senderEnd(id)).outcome,
      isA<TransferFailed>().having(
        (o) => o.failure,
        'failure',
        TransferFailure.connectionLost,
      ),
    );
    expect(File(pair.partPath(id)).lengthSync(), greaterThan(0));
  });

  test('a different device at the address is not trusted', () async {
    final pair = await Pair.start();
    final id = await pair.send(await pair.makeFile('x.bin', 1000), to: idC);
    expect(
      (await pair.senderEnd(id)).outcome,
      isA<TransferFailed>().having(
        (o) => o.failure,
        'failure',
        TransferFailure.connectionLost,
      ),
    );
    expect(pair.receiverEvents.whereType<OfferReceived>(), isEmpty);
  });

  test('a missing source file fails before connecting', () async {
    final pair = await Pair.start();
    final source = await pair.makeFile('gone.txt', 10);
    final sha = await hashOf(source);
    await source.delete();
    final id = await pair.send(source, sha256Override: sha, size: 10);
    expect(
      (await pair.senderEnd(id)).outcome,
      isA<TransferFailed>().having(
        (o) => o.failure,
        'failure',
        TransferFailure.unavailable,
      ),
    );
  });

  test('the worker isolate hashes and receives files', () async {
    final worker = await IsolateTransferBackend.spawn();
    final pair = await Pair.start(receiverBackend: worker);
    final source = await pair.makeFile('from-isolate.bin', 2 << 20);
    expect(await worker.hashFile(source.path), await hashOf(source));
    final id = await pair.send(source);
    expect((await pair.receiverEnd(id)).outcome, isA<TransferCompleted>());
    expect(await hashOf(File(pair.finalPath(id))), await hashOf(source));
  });

  test(
    '200 MB over loopback with cancel, resume and corruption; memory flat',
    () async {
      final pair = await Pair.start();
      final source = await pair.makeFile('big.bin', 200 << 20, seed: 3);
      final sha = await hashOf(source);
      final baseline = ProcessInfo.currentRss;
      var peak = baseline;
      final sampler = Timer.periodic(const Duration(milliseconds: 50), (_) {
        peak = max(peak, ProcessInfo.currentRss);
      });
      addTearDown(sampler.cancel);

      // 1. Corruption: rejected and deleted.
      final bad = await pair.send(
        source,
        sha256Override: sha256.convert([0]).toString(),
      );
      expect((await pair.receiverEnd(bad)).outcome, isA<TransferFailed>());
      await pair.senderEnd(bad);

      // 2. Cancel part-way.
      final cancelled = await pair.send(source, sha256Override: sha);
      await pair.receivedAtLeast(cancelled, 20 << 20);
      pair.sender.stop(cancelled, FileCancelReason.cancelled);
      await pair.senderEnd(cancelled);
      await pair.receiverEnd(cancelled);

      // 3. Pause part-way, then resume to the end.
      final resumed = await pair.send(source, sha256Override: sha);
      await pair.receivedAtLeast(resumed, 50 << 20);
      pair.sender.stop(resumed, FileCancelReason.paused);
      await pair.senderEnd(resumed);
      await pair.receiverEnd(resumed);
      pair.sender.upload(
        UploadRequest(
          fileId: resumed,
          chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
          peerId: idB,
          address: '127.0.0.1',
          port: pair.receiverPort,
          path: source.path,
          fileName: 'big.bin',
          fileSize: 200 << 20,
          mimeType: 'application/octet-stream',
          sha256: sha,
        ),
      );
      expect((await pair.senderEnd(resumed)).outcome, isA<TransferCompleted>());
      expect(
        (await pair.receiverEnd(resumed)).outcome,
        isA<TransferCompleted>(),
      );
      sampler.cancel();

      expect(await hashOf(File(pair.finalPath(resumed))), sha);
      final growth = (peak - baseline) >> 20;
      expect(
        growth,
        lessThan(64),
        reason: 'memory grew $growth MB while moving 200 MB',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
