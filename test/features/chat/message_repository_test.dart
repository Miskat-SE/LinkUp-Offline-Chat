import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/features/chat/data/in_memory_message_repository.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';

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
);

void main() {
  late InMemoryMessageRepository repo;

  setUp(() => repo = InMemoryMessageRepository());

  test('duplicates of an incoming message are refused', () async {
    final m = message(
      peerId: _rahim,
      direction: MessageDirection.incoming,
      minute: 1,
    );
    expect(await repo.insertIncoming(m), isTrue);
    expect(await repo.insertIncoming(m), isFalse);
  });

  test('conversations are ordered by local time, newest chat first', () async {
    await repo.insertIncoming(
      message(peerId: _rahim, direction: MessageDirection.incoming, minute: 1),
    );
    await repo.insertOutgoing(
      message(
        peerId: _karim,
        direction: MessageDirection.outgoing,
        minute: 3,
        peerName: 'Karim',
      ),
    );
    await repo.insertIncoming(
      message(peerId: _rahim, direction: MessageDirection.incoming, minute: 2),
    );

    final chats = await repo.watchConversations().first;
    expect(chats.map((c) => c.peerName), ['Karim', 'Rahim']);
    expect(chats.last.unreadCount, 2);
    expect(chats.last.lastMessage.text, 'm2');

    final rahim = await repo.watchConversation(_rahim).first;
    expect(rahim.map((m) => m.text), ['m1', 'm2']);
  });

  test('marking read clears the unread count and returns the IDs', () async {
    await repo.insertIncoming(
      message(
        peerId: _rahim,
        direction: MessageDirection.incoming,
        minute: 1,
        id: 'x',
      ),
    );
    expect(await repo.markRead(_rahim), ['x']);
    expect(await repo.markRead(_rahim), isEmpty);
    expect((await repo.watchConversations().first).single.unreadCount, 0);
  });

  test('status only moves forward, except to failed or pending', () async {
    await repo.insertOutgoing(
      message(
        peerId: _rahim,
        direction: MessageDirection.outgoing,
        minute: 1,
        id: 'o',
      ),
    );
    await repo.updateStatus('o', MessageStatus.read);
    await repo.updateStatus('o', MessageStatus.delivered);
    expect(repo.peek('o')!.status, MessageStatus.read);

    await repo.updateStatus('o', MessageStatus.failed);
    expect(repo.peek('o')!.status, MessageStatus.failed);
    await repo.updateStatus('o', MessageStatus.sent);
    expect(repo.peek('o')!.status, MessageStatus.sent);
  });

  test('pendingFor lists unsent messages oldest first', () async {
    await repo.insertOutgoing(
      message(
        peerId: _rahim,
        direction: MessageDirection.outgoing,
        minute: 2,
        id: 'b',
      ),
    );
    await repo.insertOutgoing(
      message(
        peerId: _rahim,
        direction: MessageDirection.outgoing,
        minute: 1,
        id: 'a',
      ),
    );
    await repo.insertOutgoing(
      message(
        peerId: _rahim,
        direction: MessageDirection.outgoing,
        minute: 3,
        id: 'c',
        status: MessageStatus.delivered,
      ),
    );
    expect((await repo.pendingFor(_rahim)).map((m) => m.id), ['a', 'b']);
  });
}
