import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/features/chat/data/in_memory_message_repository.dart';
import 'package:resqmesh/features/chat/data/messaging_service.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';

import '../../support/linked_pair.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';
const idC = 'cccccccc-0000-4000-8000-000000000003';

/// One phone: its repository and messaging service.
final class Phone {
  Phone(String id, String name, PairLink link)
    : repository = InMemoryMessageRepository() {
    service = MessagingService(
      links: link,
      repository: repository,
      self: () => SelfInfo(
        deviceId: id,
        name: name,
        nameClaimedAt: DateTime.utc(2026),
        announce: true,
      ),
      logger: AppLogger(),
    )..start();
  }

  final InMemoryMessageRepository repository;
  late final MessagingService service;
}

void main() {
  late LinkedPair pair;
  late Phone yusuf;
  late Phone rahim;

  /// Runs [body] on fake time with two fresh phones. The phones are made
  /// inside the fake zone so their internal futures run on fake time too.
  void run(void Function(FakeAsync async) body) => fakeAsync((async) {
    pair = LinkedPair(idA, idB);
    yusuf = Phone(idA, 'Yusuf', pair.a);
    rahim = Phone(idB, 'Rahim', pair.b);
    body(async);
  });

  /// Sends from Yusuf to Rahim and returns the message ID.
  String send(FakeAsync async, String text, {String? replyToId}) {
    late String id;
    unawaited(
      yusuf.service
          .sendText(
            peerId: idB,
            peerName: 'Rahim',
            text: text,
            replyToId: replyToId,
          )
          .then((m) => id = m.id),
    );
    async.flushMicrotasks();
    return id;
  }

  MessageStatus statusAt(InMemoryMessageRepository repo, String id) =>
      repo.peek(id)!.status;

  List<ChatMessage> conversation(
    FakeAsync async,
    InMemoryMessageRepository repo,
    String peerId,
  ) {
    late List<ChatMessage> messages;
    final sub = repo.watchConversation(peerId).listen((m) => messages = m);
    async.flushMicrotasks();
    unawaited(sub.cancel());
    return messages;
  }

  test('a message is stored, sent, delivered and read', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      final received = <ChatMessage>[];
      rahim.service.incoming.listen(received.add);

      final id = send(async, '  Are you coming?  ');
      async.flushMicrotasks();

      final atRahim = conversation(async, rahim.repository, idA).single;
      expect(atRahim.id, id);
      expect(atRahim.text, 'Are you coming?', reason: 'trimmed');
      expect(atRahim.peerName, 'Yusuf');
      expect(atRahim.isRead, isFalse);
      expect(received.single.id, id);
      expect(statusAt(yusuf.repository, id), MessageStatus.delivered);

      unawaited(rahim.service.markConversationRead(idA));
      async.flushMicrotasks();
      expect(statusAt(yusuf.repository, id), MessageStatus.read);
      expect(conversation(async, rahim.repository, idA).single.isRead, isTrue);
    });
  });

  test('a message to someone offline waits, then sends when they connect', () {
    run((async) {
      final id = send(async, 'Hello');
      expect(statusAt(yusuf.repository, id), MessageStatus.pending);
      async.elapse(const Duration(minutes: 5));
      expect(statusAt(yusuf.repository, id), MessageStatus.pending);

      pair.connect();
      async.flushMicrotasks();
      expect(statusAt(yusuf.repository, id), MessageStatus.delivered);
      expect(conversation(async, rahim.repository, idA), hasLength(1));
    });
  });

  test('queued messages arrive in the order they were written', () {
    run((async) {
      for (final text in ['one', 'two', 'three']) {
        send(async, text);
        async.elapse(const Duration(seconds: 1));
      }
      pair.connect();
      async.flushMicrotasks();
      expect(conversation(async, rahim.repository, idA).map((m) => m.text), [
        'one',
        'two',
        'three',
      ]);
    });
  });

  test('a lost ACK means a resend that is stored only once', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      final received = <ChatMessage>[];
      rahim.service.incoming.listen(received.add);
      pair.b.dropOutgoing = true; // Rahim's ACKs never arrive

      final id = send(async, 'Hello');
      async.elapse(const Duration(seconds: 25));
      expect(statusAt(yusuf.repository, id), MessageStatus.sending);
      expect(
        pair.a.sent.whereType<MessagePacket>().where(
          (p) => p.header.messageId == id,
        ),
        hasLength(3),
        reason: 'sent at 0 s, 10 s and 20 s with the same ID',
      );
      expect(conversation(async, rahim.repository, idA), hasLength(1));
      expect(received, hasLength(1), reason: 'notified once');
      expect(pair.b.sent.whereType<MessageAckPacket>(), hasLength(3));

      pair.b.dropOutgoing = false;
      async.elapse(const Duration(seconds: 10));
      // The duplicate is answered with ACK and the lost DELIVERED again.
      expect(statusAt(yusuf.repository, id), MessageStatus.delivered);
    });
  });

  test('after 5 unanswered attempts a message fails, and retry sends it', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      pair.b.dropOutgoing = true;

      final id = send(async, 'Hello');
      async.elapse(const Duration(seconds: 60));
      expect(statusAt(yusuf.repository, id), MessageStatus.failed);
      expect(pair.a.sent.whereType<MessagePacket>(), hasLength(5));

      pair.b.dropOutgoing = false;
      unawaited(yusuf.service.retry(id));
      async.flushMicrotasks();
      expect(statusAt(yusuf.repository, id), MessageStatus.delivered);
    });
  });

  test(
    'losing the connection while sending puts the message back to waiting',
    () {
      run((async) {
        pair.connect();
        async.flushMicrotasks();
        pair.b.dropOutgoing = true;
        final id = send(async, 'Hello');
        expect(statusAt(yusuf.repository, id), MessageStatus.sending);

        pair.disconnect();
        async.flushMicrotasks();
        expect(statusAt(yusuf.repository, id), MessageStatus.pending);

        pair.b.dropOutgoing = false;
        pair.connect();
        async.flushMicrotasks();
        expect(statusAt(yusuf.repository, id), MessageStatus.delivered);
      });
    },
  );

  test('a late DELIVERED never moves a read message backwards', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      pair.b.dropOutgoing = true;
      final id = send(async, 'Hello');

      PacketHeader from(String sender) => PacketHeader.create(
        senderId: sender,
        senderName: 'Rahim',
        receiverId: idA,
      );
      pair.a
        ..inject(idB, MessageReadPacket(from(idB), messageIds: [id]))
        ..inject(idB, MessageDeliveredPacket(from(idB), messageIds: [id]))
        ..inject(idB, MessageAckPacket(from(idB), ackFor: id));
      async.flushMicrotasks();
      expect(statusAt(yusuf.repository, id), MessageStatus.read);
    });
  });

  test('receipts from anyone but the recipient are ignored', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      pair.b.dropOutgoing = true;
      final id = send(async, 'Hello');

      pair.a.inject(
        idC,
        MessageReadPacket(
          PacketHeader.create(
            senderId: idC,
            senderName: 'Karim',
            receiverId: idA,
          ),
          messageIds: [id],
        ),
      );
      async.flushMicrotasks();
      expect(statusAt(yusuf.repository, id), MessageStatus.sending);
    });
  });

  test('a message addressed to someone else is ignored', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      pair.b.inject(
        idA,
        MessagePacket(
          PacketHeader.create(
            senderId: idA,
            senderName: 'Yusuf',
            receiverId: idC,
          ),
          kind: MessageKind.text,
          audience: MessageAudience.direct,
          text: 'Not for Rahim',
        ),
      );
      async.flushMicrotasks();
      expect(conversation(async, rahim.repository, idA), isEmpty);
      expect(pair.b.sent, isEmpty, reason: 'not even ACKed');
    });
  });

  test('replies keep the ID of the message they answer', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      final first = send(async, 'Are you coming?');
      send(async, 'Yes', replyToId: first);
      async.flushMicrotasks();
      final atRahim = conversation(async, rahim.repository, idA);
      expect(atRahim.last.replyToId, first);
    });
  });

  test('reading while disconnected marks the messages read locally', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      final id = send(async, 'Hello');
      pair.disconnect();
      async.flushMicrotasks();

      unawaited(rahim.service.markConversationRead(idA));
      async.flushMicrotasks();
      expect(conversation(async, rahim.repository, idA).single.isRead, isTrue);
      expect(statusAt(yusuf.repository, id), MessageStatus.delivered);
    });
  });

  test('delete removes a message on this phone only', () {
    run((async) {
      pair.connect();
      async.flushMicrotasks();
      final id = send(async, 'Hello');
      unawaited(yusuf.service.delete(id));
      async.flushMicrotasks();
      expect(conversation(async, yusuf.repository, idB), isEmpty);
      expect(conversation(async, rahim.repository, idA), hasLength(1));
    });
  });

  test('empty messages are refused', () {
    run((async) {
      Object? error;
      unawaited(
        yusuf.service
            .sendText(peerId: idB, peerName: 'Rahim', text: '   ')
            .catchError((Object e) {
              error = e;
              return Future<ChatMessage>.error(e);
            }, test: (_) => true)
            .then((_) {}, onError: (_) {}),
      );
      async.flushMicrotasks();
      expect(error, isA<ArgumentError>());
    });
  });
}
