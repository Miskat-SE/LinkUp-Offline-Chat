import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';
import 'package:resqmesh/features/chat/presentation/message_bubble.dart';

import '../../support/fake_network_monitor.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_peer_links.dart';
import '../../support/memory_datagram_network.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

/// Yusuf's app with Rahim online (or not).
final class Scenario {
  Scenario._(this.store, this.links, this.notifications, this.rahim);

  static Future<Scenario> start(
    WidgetTester tester, {
    bool rahimOnline = true,
  }) async {
    final lan = MemoryDatagramNetwork();
    final rahim = await startOtherPhone(lan, name: 'Rahim');
    final links = FakePeerLinks();
    if (!rahimOnline) links.refused.add(otherPhoneId);
    final notifications = FakeNotifications(permitted: true);
    final store = onboarded();
    await launchApp(
      tester,
      store,
      lan: lan,
      links: links,
      notifications: notifications,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    return Scenario._(store, links, notifications, rahim);
  }

  final MemoryKeyValueStore store;
  final FakePeerLinks links;
  final FakeNotifications notifications;
  final DiscoveryEngine rahim;

  String get myId => store.getString(StoreKeys.deviceId)!;

  PacketHeader get fromRahim => PacketHeader.create(
    senderId: otherPhoneId,
    senderName: 'Rahim',
    receiverId: myId,
  );

  Future<void> newChat(WidgetTester tester, String option) async {
    await tester.tap(find.text('New chat'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text(option));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await pumpFor(tester, const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await rahim.stop();
    await closeApp(tester);
  }
}

void main() {
  testWidgets('Everyone: send, then see who got it', (tester) async {
    final s = await Scenario.start(tester);
    await s.newChat(tester, 'Everyone nearby');
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('1 online now'), findsOneWidget);
    expect(find.text('Talk to everyone nearby'), findsOneWidget);

    await s.type(tester, 'Meeting in hall B');
    final packet = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    expect(packet.audience, MessageAudience.broadcast);
    expect(packet.header.receiverId, otherPhoneId);

    s.links
      ..receive(
        otherPhoneId,
        MessageAckPacket(s.fromRahim, ackFor: packet.header.messageId),
      )
      ..receive(
        otherPhoneId,
        MessageDeliveredPacket(
          s.fromRahim,
          messageIds: [packet.header.messageId],
        ),
      );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('Delivered to 1 of 1'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_rounded), findsNothing);

    // Rahim opens it: the seen count appears.
    s.links.receive(
      otherPhoneId,
      MessageReadPacket(s.fromRahim, messageIds: [packet.header.messageId]),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Seen by 1')), findsOneWidget);

    await tester.tap(find.text('Meeting in hall B'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Sent to'), findsOneWidget);
    expect(find.text('Rahim'), findsWidgets);
    expect(find.text('Read'), findsOneWidget);
    await s.finish(tester);
  });

  testWidgets('Everyone with nobody online cannot send', (tester) async {
    final s = await Scenario.start(tester, rahimOnline: false);
    await s.newChat(tester, 'Everyone nearby');
    expect(find.text('Nobody online'), findsOneWidget);
    expect(find.textContaining('Nobody is online.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Hello?');
    await tester.pump();
    final send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send_rounded),
    );
    expect(send.onPressed, isNull);
    await s.finish(tester);
  });

  testWidgets('an Everyone message from Rahim lands in the Everyone thread', (
    tester,
  ) async {
    final s = await Scenario.start(tester);
    s.links.receive(
      otherPhoneId,
      MessagePacket(
        s.fromRahim,
        kind: MessageKind.text,
        audience: MessageAudience.broadcast,
        text: 'Lunch is here',
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Everyone'), findsOneWidget);
    expect(find.text('Rahim: Lunch is here'), findsOneWidget);
    final shown = s.notifications.shown.single;
    expect(shown.title, 'Rahim · Everyone');
    expect(shown.body, 'Lunch is here');
    expect(shown.conversationId, 'everyone');

    await tester.tap(find.text('Rahim: Lunch is here'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Lunch is here'), findsOneWidget);
    expect(find.text('Rahim'), findsOneWidget, reason: 'sender shown');
    expect(
      s.links.sent.map((e) => e.$2),
      contains(isA<MessageReadPacket>()),
      reason: 'read receipt goes to Rahim',
    );
    await s.finish(tester);
  });

  testWidgets('selected people: pick, write, send', (tester) async {
    final s = await Scenario.start(tester);
    await s.newChat(tester, 'Selected people');
    expect(find.text('Select people'), findsOneWidget);
    await tester.tap(find.text('Rahim'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('1 selected'), findsOneWidget);

    await s.type(tester, 'Bring the charger');
    final packet = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    expect(packet.text, 'Bring the charger');
    expect(packet.audience, MessageAudience.direct);
    expect(find.textContaining('Sent to Rahim'), findsOneWidget);
    await s.finish(tester);
  });

  testWidgets('swipe to reply in Everyone; the reply quotes the sender', (
    tester,
  ) async {
    final s = await Scenario.start(tester);
    final lunch = MessagePacket(
      s.fromRahim,
      kind: MessageKind.text,
      audience: MessageAudience.broadcast,
      text: 'Lunch is here',
    );
    s.links.receive(otherPhoneId, lunch);
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Rahim: Lunch is here'));
    await pumpFor(tester, const Duration(seconds: 1));

    await tester.drag(find.text('Lunch is here'), const Offset(120, 0));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byIcon(Icons.close_rounded), findsOneWidget); // reply bar
    await s.type(tester, 'Coming!');
    final reply = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    expect(reply.audience, MessageAudience.broadcast);
    expect(reply.replyToId, lunch.header.messageId);
    // The quote inside the new bubble names Rahim.
    expect(find.text('Rahim'), findsWidgets);
    expect(find.text('Lunch is here'), findsNWidgets(2));
    await s.finish(tester);
  });

  testWidgets('tapping a quote scrolls back to the original', (tester) async {
    final s = await Scenario.start(tester);
    PacketHeader header() => PacketHeader.create(
      senderId: otherPhoneId,
      senderName: 'Rahim',
      receiverId: s.myId,
    );
    final first = MessagePacket(
      header(),
      kind: MessageKind.text,
      audience: MessageAudience.direct,
      text: 'The very first message',
    );
    s.links.receive(otherPhoneId, first);
    for (var i = 1; i <= 40; i++) {
      s.links.receive(
        otherPhoneId,
        MessagePacket(
          header(),
          kind: MessageKind.text,
          audience: MessageAudience.direct,
          text: 'Message number $i',
        ),
      );
    }
    s.links.receive(
      otherPhoneId,
      MessagePacket(
        header(),
        kind: MessageKind.text,
        audience: MessageAudience.direct,
        text: 'About that',
        replyToId: first.header.messageId,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('About that'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('The very first message'), findsOneWidget); // the quote

    await tester.tap(find.text('The very first message'));
    await pumpFor(tester, const Duration(seconds: 1));
    // The original is on screen now, tinted for a moment.
    final shown = tester.widget<MessageBubble>(
      find.byWidgetPredicate((w) => w is MessageBubble && w.highlighted),
    );
    expect(shown.message.text, 'The very first message');
    expect(find.text('The very first message').hitTestable(), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(
      find.byWidgetPredicate((w) => w is MessageBubble && w.highlighted),
      findsNothing,
    );
    await s.finish(tester);
  });

  testWidgets('long-press → Forward → pick a person', (tester) async {
    final s = await Scenario.start(tester);
    s.links.receive(
      otherPhoneId,
      MessagePacket(
        s.fromRahim,
        kind: MessageKind.text,
        audience: MessageAudience.broadcast,
        text: 'Bus leaves at 5',
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Rahim: Bus leaves at 5'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.longPress(find.text('Bus leaves at 5'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Forward'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Forward to'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('1 online now'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Rahim'),
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Forward'));
    await pumpFor(tester, const Duration(seconds: 1));
    final sent = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    expect(sent.text, 'Bus leaves at 5');
    expect(sent.audience, MessageAudience.direct);
    expect(find.text('Forwarded to Rahim'), findsOneWidget);
    await s.finish(tester);
  });
}
