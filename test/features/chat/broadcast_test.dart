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
import '../../support/linked_mesh.dart';
import '../../support/test_database.dart';

const yusufId = 'aaaaaaaa-0000-4000-8000-000000000001';
const rahimId = 'bbbbbbbb-0000-4000-8000-000000000002';
const karimId = 'cccccccc-0000-4000-8000-000000000003';

/// One phone: messaging and file sharing on real storage; the file engine
/// is a stand-in (fan-out over real sockets is in broadcast_loopback_test).
final class Phone {
  Phone._(
    this.id,
    this.messages,
    this.repository,
    this.transfers,
    this.backend,
    this.dir,
  );

  static Future<Phone> start(LinkedMesh mesh, String id, String name) async {
    final db = testDatabase();
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('resqmesh_bc');
    addTearDown(() => dir.delete(recursive: true));
    mesh[id].name = name;
    SelfInfo self() => SelfInfo(
      deviceId: id,
      name: name,
      nameClaimedAt: DateTime.utc(2026),
      announce: true,
    );
    final backend = FakeTransferBackend();
    final transfers = TransferService(
      backend: backend,
      repository: DriftFileTransferRepository(db),
      store: FileStore(dir),
      links: mesh[id],
      self: self,
      freeSpace: () async => 64 << 30,
      logger: AppLogger(),
    );
    await transfers.start();
    final repository = DriftMessageRepository(db);
    final messages = MessagingService(
      links: mesh[id],
      repository: repository,
      self: self,
      logger: AppLogger(),
      transfers: transfers,
      ackTimeout: const Duration(milliseconds: 150),
    )..start();
    addTearDown(messages.stop);
    return Phone._(id, messages, repository, transfers, backend, dir);
  }

  final String id;
  final MessagingService messages;
  final DriftMessageRepository repository;
  final TransferService transfers;
  final FakeTransferBackend backend;
  final Directory dir;

  Future<List<ChatMessage>> everyone() =>
      repository.watchConversation(ChatMessage.everyone).first;

  Future<List<ChatMessage>> chatWith(String peerId) =>
      repository.watchConversation(peerId).first;

  Future<Map<String, MessageStatus>> statuses(String messageId) async => {
    for (final r in await repository.recipients(messageId))
      r.recipientName: r.status,
  };

  Future<PickedFile> pick(String name) async {
    final file = File(p.join(dir.path, 'cache', name));
    await file.parent.create(recursive: true);
    await file.writeAsString('content of $name');
    return PickedFile(path: file.path, name: name);
  }
}

Future<void> settle([Duration extra = const Duration(milliseconds: 30)]) async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(extra);
}

/// Waits (real time) until [check] passes.
Future<void> eventually(Future<bool> Function() check) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!await check()) {
    if (DateTime.now().isAfter(deadline)) fail('condition never met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late LinkedMesh mesh;
  late Phone yusuf;
  late Phone rahim;
  late Phone karim;

  setUp(() async {
    mesh = LinkedMesh([yusufId, rahimId, karimId]);
    yusuf = await Phone.start(mesh, yusufId, 'Yusuf');
    rahim = await Phone.start(mesh, rahimId, 'Rahim');
    karim = await Phone.start(mesh, karimId, 'Karim');
  });

  test(
    'Everyone reaches every phone online, each tracked separately',
    () async {
      mesh.connectAll();
      await settle();
      final sent = await yusuf.messages.sendToEveryone(text: 'Meeting at 10');
      await settle();

      final message = sent.single;
      expect(message.isBroadcast, isTrue);
      expect(message.peerId, ChatMessage.everyone);
      for (final phone in [rahim, karim]) {
        final got = (await phone.everyone()).single;
        expect(got.text, 'Meeting at 10');
        expect(got.peerName, 'Yusuf');
        expect(got.senderId, yusufId);
        expect(got.isBroadcast, isTrue);
        expect(
          await phone.chatWith(yusufId),
          isEmpty,
          reason: 'not in the 1:1 chat',
        );
      }
      expect(await yusuf.statuses(message.id), {
        'Karim': MessageStatus.delivered,
        'Rahim': MessageStatus.delivered,
      });

      // Rahim opens the Everyone thread: READ goes back to Yusuf.
      await rahim.messages.markConversationRead(ChatMessage.everyone);
      await settle();
      expect(await yusuf.statuses(message.id), {
        'Karim': MessageStatus.delivered,
        'Rahim': MessageStatus.read,
      });
      final summary = DeliverySummary(
        await yusuf.repository.recipients(message.id),
      );
      expect(summary.label, 'Delivered to 2 of 2');
      expect(summary.seen, 1);
      expect(summary.overall, MessageStatus.delivered);
    },
  );

  test('only people online at that moment receive it', () async {
    mesh.connect(yusufId, rahimId); // Karim is away
    await settle();
    final message = (await yusuf.messages.sendToEveryone(text: 'Now')).single;
    await settle();
    expect((await yusuf.statuses(message.id)).keys, ['Rahim']);

    mesh.connect(yusufId, karimId);
    await settle();
    expect(await karim.everyone(), isEmpty);
  });

  test('with nobody online nothing is sent', () async {
    expect(await yusuf.messages.sendToEveryone(text: 'Hello?'), isEmpty);
    expect(await yusuf.everyone(), isEmpty);
  });

  test(
    'one recipient failing does not affect the others; retry resends',
    () async {
      mesh.connectAll();
      await settle();
      mesh[karimId].dropOutgoing = true; // Karim's ACKs never arrive
      final message = (await yusuf.messages.sendToEveryone(text: 'Hi all'))
          .single;
      await eventually(
        () async =>
            (await yusuf.statuses(message.id))['Karim'] == MessageStatus.failed,
      );
      expect(
        (await yusuf.statuses(message.id))['Rahim'],
        MessageStatus.delivered,
      );
      expect(
        mesh[yusufId].sentTo<MessagePacket>(karimId),
        hasLength(5),
        reason: '5 attempts with the same ID',
      );
      expect(await karim.everyone(), hasLength(1), reason: 'stored once');
      expect(
        DeliverySummary(await yusuf.repository.recipients(message.id)).label,
        'Delivered to 1 of 2 · 1 not sent',
      );

      mesh[karimId].dropOutgoing = false;
      await yusuf.messages.retry(message.id);
      await settle();
      expect(
        (await yusuf.statuses(message.id))['Karim'],
        MessageStatus.delivered,
      );
    },
  );

  test('a recipient who drops out gets it when they are back', () async {
    mesh.connectAll();
    await settle();
    mesh[karimId].dropOutgoing = true;
    final message = (await yusuf.messages.sendToEveryone(text: 'Hold on'))
        .single;
    await settle();
    mesh.disconnect(yusufId, karimId);
    await settle();
    expect((await yusuf.statuses(message.id))['Karim'], MessageStatus.pending);

    mesh[karimId].dropOutgoing = false;
    mesh.connect(yusufId, karimId);
    await settle();
    expect(
      (await yusuf.statuses(message.id))['Karim'],
      MessageStatus.delivered,
    );
  });

  test('read receipts in the Everyone thread go to each sender', () async {
    mesh.connectAll();
    await settle();
    final fromYusuf = (await yusuf.messages.sendToEveryone(text: 'A')).single;
    final fromRahim = (await rahim.messages.sendToEveryone(text: 'B')).single;
    await settle();
    expect((await karim.everyone()).map((m) => m.preview), [
      'Yusuf: A',
      'Rahim: B',
    ]);

    await karim.messages.markConversationRead(ChatMessage.everyone);
    await settle();
    expect((await yusuf.statuses(fromYusuf.id))['Karim'], MessageStatus.read);
    expect((await rahim.statuses(fromRahim.id))['Karim'], MessageStatus.read);
  });

  test(
    'selected people each get their own message; those away get it later',
    () async {
      mesh.connect(yusufId, rahimId); // Karim is away
      await settle();
      await yusuf.messages.sendToPeople(
        people: {rahimId: 'Rahim', karimId: 'Karim'},
        text: 'See you at 5',
      );
      await settle();
      expect((await rahim.chatWith(yusufId)).single.text, 'See you at 5');
      expect(await rahim.everyone(), isEmpty);
      final toKarim = (await yusuf.chatWith(karimId)).single;
      expect(toKarim.status, MessageStatus.pending);

      mesh.connect(yusufId, karimId);
      await settle();
      expect((await karim.chatWith(yusufId)).single.text, 'See you at 5');
      expect(
        (await yusuf.chatWith(karimId)).single.status,
        MessageStatus.delivered,
      );
    },
  );

  test('a file for several people is copied and hashed once', () async {
    mesh.connectAll();
    await settle();
    await yusuf.messages.sendToPeople(
      people: {rahimId: 'Rahim', karimId: 'Karim'},
      files: [await yusuf.pick('plan.pdf')],
    );
    await eventually(() async => yusuf.backend.uploads.length == 2);
    expect(yusuf.backend.hashes, 1);
    final uploads = yusuf.backend.uploads;
    expect(uploads.map((u) => u.peerId).toSet(), {rahimId, karimId});
    expect(uploads.map((u) => u.fileId).toSet(), hasLength(2));
    expect(
      uploads.map((u) => u.path).toSet(),
      hasLength(1),
      reason: 'one copy',
    );

    // Deleting one message keeps the copy the other still needs.
    final toRahim = (await yusuf.chatWith(rahimId)).single;
    await yusuf.messages.delete(toRahim.id);
    await settle();
    expect(File(uploads.first.path).existsSync(), isTrue);
  });

  test('a file to Everyone goes to each phone with its own transfer', () async {
    mesh.connectAll();
    await settle();
    final message = (await yusuf.messages.sendToEveryone(
      files: [await yusuf.pick('photo.jpg')],
    )).single;
    await eventually(() async => yusuf.backend.uploads.length == 2);
    expect(yusuf.backend.hashes, 1);

    for (final phone in [rahim, karim]) {
      final got = (await phone.everyone()).single;
      expect(got.isFile, isTrue);
      final transfer = await phone.transfers.find(got.fileId!);
      expect(transfer!.peerId, yusufId);
      expect(transfer.status, TransferStatus.offered);
    }
    final recipients = await yusuf.repository.recipients(message.id);
    expect(recipients.map((r) => r.fileId).toSet(), hasLength(2));
    expect(
      recipients.every((r) => r.status == MessageStatus.delivered),
      isTrue,
    );
  });

  test('after a restart, interrupted Everyone deliveries wait again', () async {
    mesh.connectAll();
    await settle();
    mesh[rahimId].dropOutgoing = true;
    final message = (await yusuf.messages.sendToEveryone(text: 'X')).single;
    await settle();
    expect((await yusuf.statuses(message.id))['Rahim'], MessageStatus.sending);
    expect(await yusuf.repository.resetInterrupted(), greaterThan(0));
    expect((await yusuf.statuses(message.id))['Rahim'], MessageStatus.pending);
  });

  test('the Everyone thread shows in the chat list with the sender', () async {
    mesh.connectAll();
    await settle();
    await yusuf.messages.sendToEveryone(text: 'Hello all');
    await settle();
    final chats = await rahim.repository.watchConversations().first;
    final everyone = chats.singleWhere((c) => c.peerId == ChatMessage.everyone);
    expect(everyone.lastMessage.preview, 'Yusuf: Hello all');
    expect(everyone.unreadCount, 1);
  });

  test('a broadcast MESSAGE is addressed to each recipient', () async {
    mesh.connectAll();
    await settle();
    final message = (await yusuf.messages.sendToEveryone(text: 'Y')).single;
    await settle();
    for (final to in [rahimId, karimId]) {
      final packet = mesh[yusufId].sentTo<MessagePacket>(to).single;
      expect(packet.header.messageId, message.id);
      expect(packet.header.receiverId, to);
      expect(packet.audience, MessageAudience.broadcast);
    }
  });
}
