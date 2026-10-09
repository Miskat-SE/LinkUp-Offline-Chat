import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

import '../support/fake_network_monitor.dart';
import '../support/fake_notifications.dart';
import '../support/fake_peer_links.dart';
import '../support/memory_datagram_network.dart';
import '../support/other_phone.dart';
import '../support/test_app.dart';

/// P11.3: every main screen, in light and dark, meets Android's touch
/// target, label and contrast guidelines, and lays out at 200% text.
const screens = [
  '/',
  '/people',
  '/settings',
  '/settings/name',
  '/settings/connection',
  '/settings/storage',
  '/settings/about',
  '/activity',
  '/select',
  '/chat/$otherPhoneId',
  '/chat/everyone',
];

Future<List<String>> audit(
  WidgetTester tester, {
  required String theme,
  double textScale = 1,
  Size? window,
  Future<void> Function()? then,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final lan = MemoryDatagramNetwork();
  final rahim = await startOtherPhone(lan, name: 'Rahim Uddin');
  final links = FakePeerLinks();
  final store = onboarded();
  await store.setString(StoreKeys.themeMode, theme);
  await launchApp(
    tester,
    store,
    lan: lan,
    links: links,
    notifications: FakeNotifications(permitted: true),
    network: FakeNetworkMonitor.onWifi('192.168.0.10'),
    settle: false,
  );
  if (window != null) {
    tester.view
      ..physicalSize = window
      ..devicePixelRatio = 2;
  }
  await pumpFor(tester, const Duration(seconds: 1));
  final me = store.getString(StoreKeys.deviceId)!;
  PacketHeader header() => PacketHeader.create(
    senderId: otherPhoneId,
    senderName: 'Rahim Uddin',
    receiverId: me,
  );
  links
    ..receive(
      otherPhoneId,
      MessagePacket(
        header(),
        kind: MessageKind.text,
        audience: MessageAudience.direct,
        text: 'Are you near the hall?',
      ),
    )
    ..receive(
      otherPhoneId,
      MessagePacket(
        header(),
        kind: MessageKind.text,
        audience: MessageAudience.broadcast,
        text: 'Lunch is here',
      ),
    );
  await pumpFor(tester, const Duration(milliseconds: 500));

  final problems = <String>[];
  for (final screen in screens) {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(screen);
    await pumpFor(tester, const Duration(seconds: 1));
    if (find.text('Page Not Found').evaluate().isNotEmpty) {
      problems.add('$screen: no such screen');
    }
    final error = tester.takeException();
    if (error != null) problems.add('$screen: ${'$error'.split('\n').first}');
    for (final (name, guideline) in [
      ('tap target', androidTapTargetGuideline),
      ('label', labeledTapTargetGuideline),
      ('contrast', textContrastGuideline),
    ]) {
      final result = await guideline.evaluate(tester);
      if (!result.passed) {
        problems.add(
          '$screen $name: ${result.reason?.split('\n').take(3).join(' / ')}',
        );
      }
    }
  }
  await then?.call();
  await rahim.stop();
  await closeApp(tester);
  return problems;
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('$theme theme meets the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      final problems = await audit(tester, theme: theme);
      handle.dispose();
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  testWidgets('every screen lays out at 200% text', (tester) async {
    final handle = tester.ensureSemantics();
    final problems = await audit(tester, theme: 'light', textScale: 2);
    handle.dispose();
    expect(
      problems.where((p) => !p.contains('contrast')),
      isEmpty,
      reason: problems.join('\n'),
    );
  });

  testWidgets('landscape phone: a side rail, and every screen lays out', (
    tester,
  ) async {
    final problems = await audit(
      tester,
      theme: 'light',
      window: const Size(1830, 820),
      then: () async {
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
    expect(
      problems.where((p) => !p.contains('contrast')),
      isEmpty,
      reason: problems.join('\n'),
    );
  });

  testWidgets('tablet: the chat opens beside the list', (tester) async {
    final problems = await audit(
      tester,
      theme: 'dark',
      window: const Size(2560, 1600),
      then: () async {
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(find.text('Pick a chat'), findsOneWidget);
        await tester.tap(find.text('Are you near the hall?'));
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(find.text('Pick a chat'), findsNothing);
        expect(find.text('Hi, Yusuf'), findsOneWidget, reason: 'list stays');
        expect(find.text('Message'), findsOneWidget, reason: 'chat opened');
        expect(
          GoRouter.of(tester.element(find.byType(Scaffold).first))
              .state
              .matchedLocation,
          '/',
        );
      },
    );
    expect(
      problems.where((p) => !p.contains('contrast')),
      isEmpty,
      reason: problems.join('\n'),
    );
  });

  testWidgets('About: what the app does, privacy and licences', (tester) async {
    await launchApp(tester, onboarded(), settle: false);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/settings');
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('About LinkUp'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(find.text('About LinkUp'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Same Wi-Fi or hotspot'), findsOneWidget);
    expect(find.textContaining('not encrypted'), findsOneWidget);
    await tester.ensureVisible(find.text('Open-source licences'));
    await tester.pump();
    await tester.tap(find.text('Open-source licences'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(LicensePage), findsOneWidget);
    await tester.pageBack();
    await pumpFor(tester, const Duration(milliseconds: 500));
    await closeApp(tester);
  });
}
