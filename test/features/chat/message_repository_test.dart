import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/storage_manager.dart';
import 'package:resqmesh/features/chat/data/drift_message_repository.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';

import '../../support/test_database.dart';

const _rahim = 'bbbbbbbb-0000-4000-8000-000000000002';
const _karim = 'cccccccc-0000-4000-8000-000000000003';
final _t0 = DateTime.utc(2026, 10, 9, 12);

int _ids = 0;

ChatMessage message({
  required String peerId,
  required MessageDirection direction,
  required int minute,
  String peerName = 'Rahim',
  MessageStatus? status,
  String? id,
  bool isRead = false,
}) => ChatMessage(
  id: id ?? 'id-${_ids++}',
  peerId: peerId,
  peerName: peerName,
  direction: direction,
  text: 'm$minute',
  sentAt: _t0,
  createdAt: _t0.add(Duration(minutes: minute)),
  status:
      status ??
      (direction == MessageDirection.incoming
          ? MessageStatus.received
          : MessageStatus.pending),
  isRead: isRead,
);

ChatMessage incoming(int minute, {String? id, String peerId = _rahim}) =>
    message(
      peerId: peerId,
      direction: MessageDirection.incoming,
      minute: minute,
      id: id,
    );

ChatMessage outgoing(
  int minute, {
  String? id,
  String peerId = _rahim,
  MessageStatus? status,
}) => message(
  peerId: peerId,
  direction: MessageDirection.outgoing,
  minute: minute,
  id: id,
  status: status,
);

void main() {
  late AppDatabase db;
  late DriftMessageRepository repo;

  setUp(() {
    db = testDatabase();
    repo = DriftMessageRepository(db);
  });
  tearDown(() => db.close());

  Future<MessageStatus?> statusOf(String id) async =>
      (await repo.find(id))?.status;

  test('a message is stored and read back unchanged', () async {
    final sent = ChatMessage(
      id: 'x',
      peerId: _rahim,
      peerName: 'Rahim',
      direction: MessageDirection.outgoing,
      text: 'আমি আসছি 👋',
      sentAt: DateTime.utc(2026, 10, 9, 12, 0, 0, 1, 2),
      createdAt: DateTime.utc(2026, 10, 9, 12, 0, 1),
      status: MessageStatus.pending,
      replyToId: 'y',
    );
    await repo.insertOutgoing(sent);
    final back = (await repo.find('x'))!;
    expect(back.text, sent.text);
    expect(back.sentAt, sent.sentAt, reason: 'microseconds kept');
    expect(back.sentAt.isUtc, isTrue);
    expect(back.createdAt, sent.createdAt);
    expect(back.replyToId, 'y');
    expect(back.isOutgoing, isTrue);
    expect(back.status, MessageStatus.pending);
  });

  test('duplicates of an incoming message are refused', () async {
    final m = incoming(1);
    expect(await repo.insertIncoming(m), isTrue);
    expect(await repo.insertIncoming(m), isFalse);
    expect(await repo.watchConversation(_rahim).first, hasLength(1));
  });

  test('conversations are ordered by local time, newest chat first', () async {
    await repo.insertIncoming(incoming(1));
    await repo.insertOutgoing(
      message(
        peerId: _karim,
        direction: MessageDirection.outgoing,
        minute: 3,
        peerName: 'Karim',
      ),
    );
    await repo.insertIncoming(incoming(2));

    final chats = await repo.watchConversations().first;
    expect(chats.map((c) => c.peerName), ['Karim', 'Rahim']);
    expect(chats.last.unreadCount, 2);
    expect(chats.last.lastMessage.text, 'm2');
    expect(chats.first.unreadCount, 0, reason: 'own messages are not unread');

    final rahim = await repo.watchConversation(_rahim).first;
    expect(rahim.map((m) => m.text), ['m1', 'm2']);
  });

  test('messages with the same time keep the order they were stored', () async {
    await repo.insertIncoming(incoming(1, id: 'first'));
    await repo.insertOutgoing(outgoing(1, id: 'second'));
    expect((await repo.watchConversation(_rahim).first).map((m) => m.id), [
      'first',
      'second',
    ]);
    final chat = (await repo.watchConversations().first).single;
    expect(chat.lastMessage.id, 'second');
  });

  test('the chat list and chats update as messages arrive', () async {
    final lists = <int>[];
    final sub = repo.watchConversations().listen(
      (chats) => lists.add(chats.fold(0, (n, c) => n + c.unreadCount)),
    );
    await pumpEventQueue();
    await repo.insertIncoming(incoming(1));
    await pumpEventQueue();
    await repo.markRead(_rahim);
    await pumpEventQueue();
    await sub.cancel();
    expect(lists, [0, 1, 0]);
  });

  test('marking read clears the unread count and returns the IDs', () async {
    await repo.insertIncoming(incoming(1, id: 'x'));
    await repo.insertOutgoing(outgoing(2, id: 'mine'));
    expect(await repo.markRead(_rahim), ['x']);
    expect(await repo.markRead(_rahim), isEmpty);
    expect((await repo.watchConversations().first).single.unreadCount, 0);
  });

  test('status only moves forward, except to failed or pending', () async {
    await repo.insertOutgoing(outgoing(1, id: 'o'));
    await repo.updateStatus('o', MessageStatus.read);
    await repo.updateStatus('o', MessageStatus.delivered);
    expect(await statusOf('o'), MessageStatus.read);

    await repo.updateStatus('o', MessageStatus.failed);
    expect(await statusOf('o'), MessageStatus.failed);
    await repo.updateStatus('o', MessageStatus.sent);
    expect(await statusOf('o'), MessageStatus.sent);
  });

  test('attempts are counted even when the status stays', () async {
    await repo.insertOutgoing(outgoing(1, id: 'o'));
    await repo.updateStatus('o', MessageStatus.sending, attempts: 1);
    await repo.updateStatus('o', MessageStatus.sending, attempts: 2);
    final m = (await repo.find('o'))!;
    expect(m.status, MessageStatus.sending);
    expect(m.attempts, 2);
  });

  test('receipts and incoming messages never get an outgoing status', () async {
    await repo.insertIncoming(incoming(1, id: 'in'));
    expect(await repo.updateStatus('in', MessageStatus.read), isNull);
    expect(await statusOf('in'), MessageStatus.received);
    expect(await repo.updateStatus('unknown', MessageStatus.read), isNull);
  });

  test('pendingFor lists unsent messages oldest first', () async {
    await repo.insertOutgoing(outgoing(2, id: 'b'));
    await repo.insertOutgoing(outgoing(1, id: 'a'));
    await repo.insertOutgoing(
      outgoing(3, id: 'c', status: MessageStatus.delivered),
    );
    await repo.insertOutgoing(
      outgoing(4, id: 'd', status: MessageStatus.sending),
    );
    await repo.insertOutgoing(outgoing(0, id: 'other', peerId: _karim));
    expect((await repo.pendingFor(_rahim)).map((m) => m.id), ['a', 'b', 'd']);
  });

  test(
    'after a restart, interrupted sends wait again with fresh attempts',
    () async {
      await repo.insertOutgoing(outgoing(1, id: 'a'));
      await repo.updateStatus('a', MessageStatus.sending, attempts: 3);
      await repo.insertOutgoing(
        outgoing(2, id: 'b', status: MessageStatus.delivered),
      );
      expect(await repo.resetInterrupted(), 1);
      final a = (await repo.find('a'))!;
      expect(a.status, MessageStatus.pending);
      expect(a.attempts, 0);
      expect(await statusOf('b'), MessageStatus.delivered);
    },
  );

  test('receipts owed are tracked until sent, and never move back', () async {
    await repo.insertIncoming(incoming(1, id: 'a'));
    await repo.insertIncoming(incoming(2, id: 'b'));
    await repo.insertIncoming(incoming(3, id: 'k', peerId: _karim));
    expect(await repo.owedReceipts(_rahim, Receipt.delivered), ['a', 'b']);
    expect(await repo.owedReceipts(_rahim, Receipt.read), isEmpty);

    await repo.recordReceipts(['a'], Receipt.delivered);
    expect(await repo.owedReceipts(_rahim, Receipt.delivered), ['b']);

    // Reading makes READ owed; DELIVERED is no longer needed.
    await repo.markRead(_rahim);
    expect(await repo.owedReceipts(_rahim, Receipt.delivered), isEmpty);
    expect(await repo.owedReceipts(_rahim, Receipt.read), ['a', 'b']);

    await repo.recordReceipts(['a', 'b'], Receipt.read);
    await repo.recordReceipts(['a'], Receipt.delivered); // late; ignored
    expect(await repo.owedReceipts(_rahim, Receipt.read), isEmpty);
    expect(await repo.owedReceipts(_rahim, Receipt.delivered), isEmpty);
  });

  test('delete removes one message', () async {
    await repo.insertIncoming(incoming(1, id: 'a'));
    await repo.insertIncoming(incoming(2, id: 'b'));
    await repo.delete('a');
    expect((await repo.watchConversation(_rahim).first).map((m) => m.id), [
      'b',
    ]);
  });

  test('stored codes are stable (they are part of the schema)', () async {
    await repo.insertOutgoing(outgoing(1, id: 'o'));
    await repo.insertIncoming(incoming(2, id: 'i'));
    final rows = await db
        .customSelect(
          'SELECT message_id, direction, status, receipt_sent FROM messages '
          'ORDER BY message_id',
        )
        .get();
    expect(rows.map((r) => r.data), [
      {
        'message_id': 'i',
        'direction': 'in',
        'status': 'received',
        'receipt_sent': 'none',
      },
      {
        'message_id': 'o',
        'direction': 'out',
        'status': 'pending',
        'receipt_sent': 'none',
      },
    ]);
  });

  test('an unknown status from a newer version shows as failed', () async {
    await repo.insertOutgoing(outgoing(1, id: 'o'));
    await db.customStatement(
      "UPDATE messages SET status = 'scheduled' WHERE message_id = 'o'",
    );
    expect(await statusOf('o'), MessageStatus.failed);
  });

  test(
    'clearing chat history deletes everything and updates the count',
    () async {
      final storage = StorageManager(db);
      final counts = <int>[];
      final sub = storage.watchMessageCount().listen(counts.add);
      await repo.insertIncoming(incoming(1));
      await repo.insertOutgoing(outgoing(2));
      await pumpEventQueue();
      expect(await storage.clearChatHistory(), 2);
      await pumpEventQueue();
      await sub.cancel();
      expect(counts.last, 0);
      expect(counts, contains(2));
      expect(await repo.watchConversations().first, isEmpty);
    },
  );

  test('messages survive closing and reopening the database file', () async {
    final dir = await Directory.systemTemp.createTemp('resqmesh_db');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/resqmesh.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await DriftMessageRepository(first).insertOutgoing(outgoing(1, id: 'kept'));
    await first.close();

    final second = AppDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened = DriftMessageRepository(second);
    expect((await reopened.find('kept'))?.status, MessageStatus.pending);
    expect((await reopened.pendingFor(_rahim)).single.id, 'kept');
  });
}
