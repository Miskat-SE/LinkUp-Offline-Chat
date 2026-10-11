import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/app/background_coordinator.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

import '../support/fake_background_service.dart';
import '../support/fake_peer_links.dart';
import '../support/fake_transfer_backend.dart';
import '../support/test_database.dart';

const me = 'aaaaaaaa-0000-4000-8000-000000000001';
const rahim = 'bbbbbbbb-0000-4000-8000-000000000002';

FileTransfer transfer(
  String id, {
  bool outgoing = false,
  int size = 1000,
  int bytes = 0,
  TransferStatus status = TransferStatus.inProgress,
}) => FileTransfer(
  fileId: id,
  messageId: 'm$id',
  peerId: rahim,
  direction: outgoing ? TransferDirection.outgoing : TransferDirection.incoming,
  name: 'file$id.jpg',
  mimeType: 'image/jpeg',
  size: size,
  bytesTransferred: bytes,
  status: status,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('notification wording', () {
    test('idle: reachable, or stopped', () {
      final idle = BackgroundCoordinator.describe([], stayReachable: false);
      expect(idle.transferring, isFalse);
      expect(idle.stayReachable, isFalse, reason: 'service stops');
      final reachable = BackgroundCoordinator.describe([], stayReachable: true);
      expect(reachable.title, 'LinkUp is reachable');
      expect(reachable.route, '/');
    });

    test('one file: "Receiving video.mp4 — 62%", opens its details', () {
      final state = BackgroundCoordinator.describe([
        (
          transfer('1', size: 100 << 20),
          TransferProgress(
            bytes: 62 << 20,
            total: 100 << 20,
            bytesPerSecond: 2.0 * (1 << 20),
          ),
        ),
      ], stayReachable: false);
      expect(state.transferring, isTrue);
      expect(state.title, 'Receiving file1.jpg — 62%');
      expect(state.text, '62.0 MB of 100 MB · 2.0 MB/s · 19 s left');
      expect(state.progress, 62);
      expect(state.route, '/files/1/details');
    });

    test('several files: counts and overall progress, opens Activity', () {
      final state = BackgroundCoordinator.describe([
        (transfer('1', outgoing: true, bytes: 500), null),
        (transfer('2', outgoing: true), null),
        (transfer('3', bytes: 1000), null),
      ], stayReachable: true);
      expect(state.title, 'Sending 2 files · receiving 1');
      expect(state.progress, 50);
      expect(state.route, '/activity');
    });

    test('preparing shows an indeterminate bar', () {
      final state = BackgroundCoordinator.describe([
        (transfer('1', outgoing: true, status: TransferStatus.preparing), null),
      ], stayReachable: false);
      expect(state.title, startsWith('Preparing file1.jpg'));
      expect(state.progress, isNull);
    });
  });

  test('the service follows transfers, at most once a second', () async {
    final db = testDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('resqmesh_bg');
    addTearDown(() => dir.delete(recursive: true));
    final backend = FakeTransferBackend();
    final service = TransferService(
      backend: backend,
      repository: DriftFileTransferRepository(db),
      store: FileStore(dir),
      links: FakePeerLinks(),
      self: () => SelfInfo(
        deviceId: me,
        name: 'Yusuf',
        nameClaimedAt: DateTime.utc(2026),
        announce: true,
      ),
      freeSpace: () async => 64 << 30,
      logger: AppLogger(),
    );
    await service.start();
    final background = FakeBackgroundService();
    var stayReachable = false;
    final coordinator = BackgroundCoordinator(
      transfers: service,
      service: background,
      stayReachable: () => stayReachable,
      interval: const Duration(milliseconds: 300),
    )..start();
    addTearDown(coordinator.stop);
    Future<void> settle([int ms = 50]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    // Real time: under a busy test run, wait for the state, not a fixed time.
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await settle(20);
      }
    }

    await settle();
    expect(background.running, isFalse);

    // Rahim starts sending a photo.
    const id = '0a4e6c1d-2b8f-4e57-a3c9-000000000001';
    await service.registerIncoming(
      const FileRef(
        fileId: id,
        name: 'photo.jpg',
        size: 1000,
        mimeType: 'image/jpeg',
        sha256:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
      peerId: rahim,
      messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
    );
    backend.emit(
      OfferReceived(
        FileOfferPacket(
          PacketHeader.create(
            senderId: rahim,
            senderName: 'Rahim',
            receiverId: me,
          ),
          fileId: id,
          chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
          fileName: 'photo.jpg',
          fileSize: 1000,
          mimeType: 'image/jpeg',
          sha256: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        peerId: rahim,
      ),
    );
    await settle();
    backend.emit(const TransferStarted(id, offset: 0));
    for (var b = 100; b <= 600; b += 100) {
      backend.emit(TransferProgressed(id, bytes: b));
    }
    await until(() => background.last?.title == 'Receiving photo.jpg — 60%');
    expect(background.running, isTrue);
    expect(background.last!.transferring, isTrue);
    expect(background.last!.title, 'Receiving photo.jpg — 60%');
    expect(
      background.states.where((s) => s.transferring).length,
      lessThanOrEqualTo(3),
      reason: 'six progress events, about one update per interval',
    );

    // Done: the service stops (Stay reachable is off).
    backend.emit(const TransferEnded(id, TransferCompleted()));
    await until(() => !background.running);
    expect(background.running, isFalse);

    // Stay reachable on: it runs while idle.
    stayReachable = true;
    await coordinator.refresh();
    expect(background.running, isTrue);
    expect(background.last!.transferring, isFalse);
  });
}
