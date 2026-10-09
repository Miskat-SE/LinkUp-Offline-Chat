import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';

import '../../support/fake_network_monitor.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_peer_links.dart';
import '../../support/memory_datagram_network.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';
import '../../support/test_database.dart';

/// The app as Yusuf, with Rahim discovered and connected.
final class ChatScenario {
  ChatScenario._(this.store, this.links, this.notifications, this.rahim);

  static Future<ChatScenario> start(
    WidgetTester tester, {
    bool notificationsAllowed = true,
    bool rahimReachable = true,
    AppDatabase? database,
  }) async {
    final lan = MemoryDatagramNetwork();
    final rahim = await startOtherPhone(lan, name: 'Rahim');
    final links = FakePeerLinks();
    if (!rahimReachable) links.refused.add(otherPhoneId);
    final notifications = FakeNotifications(permitted: notificationsAllowed);
    final store = onboarded();
    await launchApp(
      tester,
      store,
      lan: lan,
      links: links,
      notifications: notifications,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      database: database,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    return ChatScenario._(store, links, notifications, rahim);
  }

  final MemoryKeyValueStore store;
  final FakePeerLinks links;
  final FakeNotifications notifications;
  final DiscoveryEngine rahim;

  String get myId => store.getString(StoreKeys.deviceId)!;

  PacketHeader fromRahim({String? messageId}) => PacketHeader(
    messageId:
        messageId ??
        PacketHeader.create(
          senderId: otherPhoneId,
          senderName: 'Rahim',
        ).messageId,
    senderId: otherPhoneId,
    senderName: 'Rahim',
    receiverId: myId,
    timestamp: DateTime.now().toUtc(),
  );

  /// Rahim sends [text] to Yusuf.
  void rahimSays(String text) => links.receive(
    otherPhoneId,
    MessagePacket(
      fromRahim(),
      kind: MessageKind.text,
      audience: MessageAudience.direct,
      text: text,
    ),
  );

  /// The last chat message Yusuf sent.
  MessagePacket get lastSent =>
      links.sent.map((s) => s.$2).whereType<MessagePacket>().last;

  Future<void> openChatFromPeople(WidgetTester tester) async {
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Chat'));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byType(TextField),
      ),
      text,
    );
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
  testWidgets('send from People: the message shows Sent, then Delivered', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final s = await ChatScenario.start(tester);
    await s.openChatFromPeople(tester);

    expect(find.text('Say hello to Rahim'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    await s.send(tester, 'Are you coming?');

    expect(find.text('Are you coming?'), findsOneWidget);
    expect(s.lastSent.text, 'Are you coming?');
    expect(s.lastSent.header.receiverId, otherPhoneId);
    expect(
      find.bySemanticsLabel(RegExp('Are you coming.*Sending')),
      findsOneWidget,
    );

    final id = s.lastSent.header.messageId;
    s.links.receive(otherPhoneId, MessageAckPacket(s.fromRahim(), ackFor: id));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(
      find.bySemanticsLabel(RegExp('Are you coming.*Sent')),
      findsOneWidget,
    );

    s.links.receive(
      otherPhoneId,
      MessageDeliveredPacket(s.fromRahim(), messageIds: [id]),
    );
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(
      find.bySemanticsLabel(RegExp('Are you coming.*Delivered')),
      findsOneWidget,
    );
    semantics.dispose();
    await s.finish(tester);
  });

  testWidgets(
    'a new message appears in Chats with a badge and a notification',
    (tester) async {
      final s = await ChatScenario.start(tester);
      s.rahimSays('Meeting at 10 PM');
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(find.text('Meeting at 10 PM'), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'unread badge');
      expect(s.notifications.shown.single.title, 'Rahim');
      expect(s.notifications.shown.single.body, 'Meeting at 10 PM');
      expect(
        s.links.sent.map((p) => p.$2),
        containsAll([isA<MessageAckPacket>(), isA<MessageDeliveredPacket>()]),
      );

      await tester.tap(find.text('Meeting at 10 PM'));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(s.links.sent.map((p) => p.$2), contains(isA<MessageReadPacket>()));
      expect(s.notifications.cancelled, contains(otherPhoneId));

      // Messages arriving while the chat is open are read and not notified.
      s.rahimSays('See you there');
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.text('See you there'), findsOneWidget);
      expect(s.notifications.shown, hasLength(1));
      await s.finish(tester);
    },
  );

  testWidgets('the first chat explains notifications before asking', (
    tester,
  ) async {
    final s = await ChatScenario.start(tester, notificationsAllowed: false);
    await s.openChatFromPeople(tester);

    expect(find.text('Get notified about new messages'), findsOneWidget);
    await tester.tap(find.text('Turn on notifications'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(s.notifications.permissionRequests, 1);
    expect(s.store.getString(StoreKeys.notificationsAsked), isNotNull);
    await s.finish(tester);
  });

  testWidgets('long press offers copy, reply and delete', (tester) async {
    // The test environment has no clipboard; record what is copied.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final s = await ChatScenario.start(tester);
    await s.openChatFromPeople(tester);
    await s.send(tester, 'First message');

    await tester.longPress(find.text('First message'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Copy'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Message copied'), findsOneWidget);
    expect(copied, 'First message');
    await pumpFor(tester, const Duration(seconds: 2)); // confirmation gone

    await tester.longPress(find.text('First message'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Reply'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('Replying to You'), findsOneWidget);
    await s.send(tester, 'Second message');
    expect(s.lastSent.replyToId, isNotNull);
    expect(find.text('Replying to You'), findsNothing);
    // The reply quotes the first message.
    expect(find.text('First message'), findsNWidgets(2));

    await tester.longPress(find.text('Second message'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Delete'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Second message'), findsNothing);
    await s.finish(tester);
  });

  testWidgets('messages to someone not connected wait to be sent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final s = await ChatScenario.start(tester, rahimReachable: false);
    await s.openChatFromPeople(tester);

    expect(find.textContaining("Rahim isn't connected"), findsOneWidget);
    await s.send(tester, 'Hello?');
    expect(
      find.bySemanticsLabel(RegExp('Hello.*Waiting to send')),
      findsOneWidget,
    );
    expect(s.links.sent, isEmpty);
    semantics.dispose();
    await s.finish(tester);
  });

  testWidgets('tapping a notification opens that chat', (tester) async {
    final s = await ChatScenario.start(tester);
    s.notifications.tap(otherPhoneId);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Rahim'), findsWidgets);
    await s.finish(tester);
  });

  testWidgets('chats and unread badges are still there after a restart', (
    tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    final s = await ChatScenario.start(tester, database: db);
    s.rahimSays('Meeting at 10 PM');
    await pumpFor(tester, const Duration(milliseconds: 500));
    await s.finish(tester);

    // Started again: same phone, same database, nobody nearby yet.
    await launchApp(tester, s.store, database: db, settle: false);
    expect(find.text('Meeting at 10 PM'), findsOneWidget);
    expect(find.text('1'), findsOneWidget, reason: 'still unread');
    await tester.tap(find.text('Meeting at 10 PM'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Rahim'), findsWidgets, reason: 'name kept offline');
    await closeApp(tester);
  });

  testWidgets('Storage shows the message count and clears chat history', (
    tester,
  ) async {
    final s = await ChatScenario.start(tester);
    s
      ..rahimSays('One')
      ..rahimSays('Two');
    await pumpFor(tester, const Duration(milliseconds: 500));

    await tester.tap(find.text('Settings'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('Storage').last,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('2 messages'));
    await tester.tap(find.text('2 messages'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('2 messages saved'), findsOneWidget);

    await tester.tap(find.text('Clear chat history'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('All 2 messages on this phone'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('2 messages saved'), findsOneWidget);

    await tester.tap(find.text('Clear chat history'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Clear history'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('No messages saved'), findsOneWidget);
    expect(find.text('Chat history cleared'), findsOneWidget);

    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Chats'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('No chats yet'), findsOneWidget);
    await s.finish(tester);
  });
}
