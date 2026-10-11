import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/chat/data/drift_message_repository.dart';
import 'package:resqmesh/features/chat/data/messaging_service.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

import '../../support/linked_mesh.dart';
import '../../support/test_database.dart';

const yusufId = 'aaaaaaaa-0000-4000-8000-000000000001';
const rahimId = 'bbbbbbbb-0000-4000-8000-000000000002';
const karimId = 'cccccccc-0000-4000-8000-000000000003';

/// A phone with the real messaging service, database, transfer service and
/// transfer engine; files move over real sockets on loopback.
final class Phone {
  Phone._(this.messages, this.repository, this.transfers, this.store);

  static Future<Phone> start(LinkedMesh mesh, String id, String name) async {
    final db = testDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('resqmesh_mesh');
    addTearDown(() => dir.delete(recursive: true));
    mesh[id].name = name;
    SelfInfo self() => SelfInfo(
      deviceId: id,
      name: name,
      nameClaimedAt: DateTime.utc(2026),
      announce: true,
    );
    final store = FileStore(dir);
    final transfers = TransferService(
      backend: TransferEngine(
        preferredPort: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      ),
      repository: DriftFileTransferRepository(db),
      store: store,
      links: mesh[id],
      self: self,
      freeSpace: () async => 64 << 30,
      logger: AppLogger(),
    );
    await transfers.start();
    addTearDown(transfers.stop);
    final repository = DriftMessageRepository(db);
    final messages = MessagingService(
      links: mesh[id],
      repository: repository,
      self: self,
      logger: AppLogger(),
      transfers: transfers,
    )..start();
    addTearDown(messages.stop);
    return Phone._(messages, repository, transfers, store);
  }

  final MessagingService messages;
  final DriftMessageRepository repository;
  final TransferService transfers;
  final FileStore store;
}

Future<void> eventually(Future<bool> Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (!await check()) {
    if (DateTime.now().isAfter(deadline)) fail('condition never met');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  test(
    '3 phones: a broadcast text and file arrive, with per-person status',
    () async {
      final mesh = LinkedMesh([yusufId, rahimId, karimId]);
      final yusuf = await Phone.start(mesh, yusufId, 'Yusuf');
      final rahim = await Phone.start(mesh, rahimId, 'Rahim');
      final karim = await Phone.start(mesh, karimId, 'Karim');
      mesh.connectAll();

      // A 3 MB file, picked into Yusuf's cache.
      final source = File(p.join(yusuf.store.root.path, 'cache', 'video.mp4'));
      await source.parent.create(recursive: true);
      final random = Random(9);
      await source.writeAsBytes(
        Uint8List.fromList(List.generate(3 << 20, (_) => random.nextInt(256))),
      );
      final sha = sha256.convert(await source.readAsBytes()).toString();

      final sent = await yusuf.messages.sendToEveryone(
        text: 'Video from today',
        files: [PickedFile(path: source.path, name: 'video.mp4')],
      );
      expect(sent, hasLength(2));
      final fileMessage = sent.last;

      for (final phone in [rahim, karim]) {
        await eventually(() async {
          final thread = await phone.repository
              .watchConversation(ChatMessage.everyone)
              .first;
          if (thread.length != 2) return false;
          final transfer = await phone.transfers.find(thread.last.fileId!);
          return transfer?.status == TransferStatus.completed;
        });
        final thread = await phone.repository
            .watchConversation(ChatMessage.everyone)
            .first;
        expect(thread.first.text, 'Video from today');
        expect(thread.first.peerName, 'Yusuf');
        final transfer = (await phone.transfers.find(thread.last.fileId!))!;
        final received = phone.store.file(transfer.localPath!);
        expect(
          sha256.convert(await received.readAsBytes()).toString(),
          sha,
          reason: 'byte-identical',
        );
      }

      // Yusuf sees each person's status, and both transfers completed.
      await eventually(() async {
        final recipients = await yusuf.repository.recipients(fileMessage.id);
        final done = <bool>[];
        for (final r in recipients) {
          final t = await yusuf.transfers.find(r.fileId!);
          done.add(t?.status == TransferStatus.completed);
        }
        return done.length == 2 && done.every((d) => d);
      });
      for (final message in sent) {
        final summary = DeliverySummary(
          await yusuf.repository.recipients(message.id),
        );
        expect(summary.total, 2);
        expect(summary.count(MessageStatus.delivered), 2);
        expect(summary.label, 'Delivered to 2 of 2');
      }
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('a received file is forwarded from the copy on the phone', () async {
    final mesh = LinkedMesh([yusufId, rahimId, karimId]);
    final yusuf = await Phone.start(mesh, yusufId, 'Yusuf');
    final rahim = await Phone.start(mesh, rahimId, 'Rahim');
    final karim = await Phone.start(mesh, karimId, 'Karim');
    mesh.connectAll();

    final source = File(p.join(yusuf.store.root.path, 'cache', 'map.pdf'));
    await source.parent.create(recursive: true);
    final random = Random(4);
    await source.writeAsBytes(
      Uint8List.fromList(List.generate(1 << 20, (_) => random.nextInt(256))),
    );
    final sha = sha256.convert(await source.readAsBytes()).toString();
    await yusuf.messages.sendFiles(
      peerId: rahimId,
      peerName: 'Rahim',
      files: [PickedFile(path: source.path, name: 'map.pdf')],
    );

    Future<ChatMessage?> fileAt(Phone phone, String chat) async {
      final thread = await phone.repository.watchConversation(chat).first;
      final file = thread.where((m) => m.isFile).firstOrNull;
      if (file == null) return null;
      final transfer = await phone.transfers.find(file.fileId!);
      return transfer?.status == TransferStatus.completed ? file : null;
    }

    await eventually(() async => await fileAt(rahim, yusufId) != null);
    final received = (await fileAt(rahim, yusufId))!;

    // Rahim forwards it to Karim, and the text of a message to everyone.
    expect(
      await rahim.messages.forward(received, people: {karimId: 'Karim'}),
      isTrue,
    );
    await eventually(() async => await fileAt(karim, rahimId) != null);
    final forwarded = (await fileAt(karim, rahimId))!;
    final transfer = (await karim.transfers.find(forwarded.fileId!))!;
    expect(
      sha256
          .convert(await karim.store.file(transfer.localPath!).readAsBytes())
          .toString(),
      sha,
    );
    expect(transfer.name, 'map.pdf');
    // Rahim's own copy is untouched and no temporary copy is left.
    expect(await rahim.transfers.find(received.fileId!), isNotNull);
    final leftovers = Directory(p.join(rahim.store.root.path, 'forward'));
    expect(
      leftovers.existsSync() ? leftovers.listSync() : const <Object>[],
      isEmpty,
    );
  }, timeout: const Timeout(Duration(minutes: 1)));
}
