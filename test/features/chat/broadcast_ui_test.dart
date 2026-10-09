import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';

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

    await tester.tap(find.text('Meeting in hall B'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Sent to'), findsOneWidget);
    expect(find.text('Rahim'), findsWidgets);
    expect(find.text('Delivered'), findsOneWidget);
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
}
