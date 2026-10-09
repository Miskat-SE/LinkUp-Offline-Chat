import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/features/chat/data/drift_message_repository.dart';
import 'package:resqmesh/features/chat/data/messaging_service.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';

import '../../support/fake_transfer_backend.dart';
import '../../support/linked_pair.dart';
import '../../support/test_database.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';

/// One phone with messaging and file sharing on real storage; the file
/// engine is a stand-in (it is tested on loopback separately).
final class Phone {
  Phone._(this.dir, this.messages, this.transfers, this.backend, this.store);

  static Future<Phone> start(String id, String name, PairLink link) async {
    final db = testDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('resqmesh_phone');
    addTearDown(() => dir.delete(recursive: true));
    SelfInfo self() => SelfInfo(
      deviceId: id,
      name: name,
      nameClaimedAt: DateTime.utc(2026),
      announce: true,
    );
    final backend = FakeTransferBackend();
    final store = FileStore(dir);
    final transfers = TransferService(
      backend: backend,
      repository: DriftFileTransferRepository(db),
      store: store,
      links: link,
      self: self,
      freeSpace: () async => 64 << 30,
      logger: AppLogger(),
    );
    await transfers.start();
    final messages = MessagingService(
      links: link,
      repository: DriftMessageRepository(db),
      self: self,
      logger: AppLogger(),
      transfers: transfers,
    )..start();
    addTearDown(messages.stop);
    return Phone._(dir, messages, transfers, backend, store);
  }

  final Directory dir;
  final MessagingService messages;
  final TransferService transfers;
  final FakeTransferBackend backend;
  final FileStore store;

  Future<PickedFile> pick(String name) async {
    final file = File(p.join(dir.path, 'cache', name));
    await file.parent.create(recursive: true);
    await file.writeAsString('hello from $name');
    return PickedFile(path: file.path, name: name);
  }
}

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  late LinkedPair pair;
  late Phone yusuf;
  late Phone rahim;

  setUp(() async {
    pair = LinkedPair(idA, idB);
    yusuf = await Phone.start(idA, 'Yusuf', pair.a);
    rahim = await Phone.start(idB, 'Rahim', pair.b);
  });

  test(
    'a file sent while offline is announced, confirmed, then uploaded',
    () async {
      final sent = await yusuf.messages.sendFiles(
        peerId: idB,
        peerName: 'Rahim',
        files: [await yusuf.pick('photo.jpg')],
      );
      final message = sent.single;
      expect(message.isFile, isTrue);
      await settle();
      final fileId = message.fileId!;
      expect(
        (await yusuf.transfers.find(fileId))!.status,
        TransferStatus.offered,
      );
      expect(pair.a.sent, isEmpty, reason: 'Rahim is away');

      pair.connect();
      await settle();
      final packet = pair.a.sent.whereType<MessagePacket>().single;
      expect(packet.kind, MessageKind.file);
      expect(packet.file!.fileId, fileId);
      expect(packet.file!.name, 'photo.jpg');
      expect(packet.file!.sha256, yusuf.backend.hash);

      // Rahim stored the message and expects the file.
      final atRahim = await rahim.transfers.find(fileId);
      expect(atRahim!.status, TransferStatus.offered);
      expect(atRahim.isOutgoing, isFalse);
      expect(atRahim.peerId, idA);

      // The confirmation lets the data follow.
      final upload = yusuf.backend.uploads.single;
      expect(upload.fileId, fileId);
      expect(upload.peerId, idB);
      expect(upload.port, 28762);
      expect(
        (await yusuf.transfers.find(fileId))!.status,
        TransferStatus.inProgress,
      );
    },
  );

  test('the chat list and notifications name the file', () async {
    pair.connect();
    await settle();
    final received = <ChatMessage>[];
    rahim.messages.incoming.listen(received.add);
    await yusuf.messages.sendFiles(
      peerId: idB,
      peerName: 'Rahim',
      files: [await yusuf.pick('../../evil name?.pdf')],
    );
    await settle();
    expect(received.single.preview, '📎 evil name_.pdf');
  });

  test('deleting a file message stops and removes its file', () async {
    final sent = await yusuf.messages.sendFiles(
      peerId: idB,
      peerName: 'Rahim',
      files: [await yusuf.pick('x.zip')],
    );
    await settle();
    final fileId = sent.single.fileId!;
    expect(yusuf.store.file(FileStore.sentPath(fileId)).existsSync(), isTrue);
    await yusuf.messages.delete(sent.single.id);
    await settle();
    expect(await yusuf.transfers.find(fileId), isNull);
    expect(yusuf.store.file(FileStore.sentPath(fileId)).existsSync(), isFalse);
  });

  test('a file message reusing someone else\'s file ID is ignored', () async {
    pair.connect();
    await settle();
    final sent = await yusuf.messages.sendFiles(
      peerId: idB,
      peerName: 'Rahim',
      files: [await yusuf.pick('mine.txt')],
    );
    await settle();
    // Rahim (or an impostor) now claims the same file ID back to Yusuf.
    pair.a.inject(
      idB,
      MessagePacket(
        PacketHeader.create(
          senderId: idB,
          senderName: 'Rahim',
          receiverId: idA,
        ),
        kind: MessageKind.file,
        audience: MessageAudience.direct,
        file: FileRef(
          fileId: sent.single.fileId!,
          name: 'trick.txt',
          size: 1,
          mimeType: 'text/plain',
          sha256: 'c' * 64,
        ),
      ),
    );
    await settle();
    expect(pair.a.sent.whereType<MessageAckPacket>(), isEmpty);
  });
}
