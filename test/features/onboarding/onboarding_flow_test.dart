import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/presentation/home_screen.dart';
import 'package:resqmesh/features/discovery/presentation/people_screen.dart';

import '../../support/memory_key_value_store.dart';
import '../../support/test_app.dart';

/// A device that finished onboarding earlier.
MemoryKeyValueStore onboardedStore() => MemoryKeyValueStore({
  StoreKeys.username: 'Yusuf',
  StoreKeys.connectionMethod: 'wifiRouter',
});

void main() {
  testWidgets('first launch: welcome, name, connection method, Home', (
    tester,
  ) async {
    final store = MemoryKeyValueStore();
    await launchApp(tester, store);

    expect(find.text('Talk when the internet is down'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'T');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 2 characters'), findsOneWidget);
    expect(store.getString(StoreKeys.username), isNull);

    await tester.enterText(find.byType(TextField), '  Yusuf  ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(store.getString(StoreKeys.username), 'Yusuf');

    expect(find.text('How do you want to connect?'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2));
    await tester.tap(find.text('Phone hotspot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Hi, Yusuf'), findsOneWidget);
    expect(store.getString(StoreKeys.connectionMethod), 'hotspot');
  });

  testWidgets('methods marked Coming soon cannot be chosen', (tester) async {
    final store = MemoryKeyValueStore({StoreKeys.username: 'Yusuf'});
    await launchApp(tester, store);

    await tester.tap(find.text('Bluetooth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // The default (Wi-Fi network) stays selected.
    expect(store.getString(StoreKeys.connectionMethod), 'wifiRouter');
  });

  testWidgets('a device with a name only has to pick a connection method', (
    tester,
  ) async {
    final store = MemoryKeyValueStore({StoreKeys.username: 'Yusuf'});
    await launchApp(tester, store);

    expect(find.text('How do you want to connect?'), findsOneWidget);
    expect(find.text('Choose your name'), findsNothing);
  });

  testWidgets('a relaunch after onboarding opens Home', (tester) async {
    await launchApp(tester, onboardedStore());

    expect(find.text('Talk when the internet is down'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the device ID survives a relaunch', (tester) async {
    final store = MemoryKeyValueStore();
    await launchApp(tester, store);
    final firstId = store.getString(StoreKeys.deviceId);

    await launchApp(tester, store);
    expect(store.getString(StoreKeys.deviceId), firstId);
  });

  testWidgets('the tabs switch between Chats, People and Settings', (
    tester,
  ) async {
    await launchApp(tester, onboardedStore());

    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.byType(PeopleScreen), findsOneWidget);

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('New chat lists the three ways to start a conversation', (
    tester,
  ) async {
    await launchApp(tester, onboardedStore());

    await tester.tap(find.text('New chat'));
    await tester.pumpAndSettle();
    expect(find.text('One person'), findsOneWidget);
    expect(find.text('Everyone nearby'), findsOneWidget);
    expect(find.text('Selected people'), findsOneWidget);
  });

  testWidgets('Settings → Change name saves the new name', (tester) async {
    final store = onboardedStore();
    await launchApp(tester, store);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Yusuf'), findsOneWidget);

    await tester.tap(find.text('Change name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Rahim');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.getString(StoreKeys.username), 'Rahim');
    expect(find.text('Rahim'), findsOneWidget);
    expect(find.text('Name changed to “Rahim”'), findsOneWidget);
  });

  testWidgets('the connection card on Home changes the method', (tester) async {
    final store = onboardedStore();
    await launchApp(tester, store);

    await tester.tap(find.text('Change how you connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phone hotspot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.getString(StoreKeys.connectionMethod), 'hotspot');
    expect(find.text('Now connecting with Phone hotspot'), findsOneWidget);
  });

  testWidgets('the theme choice is stored', (tester) async {
    final store = onboardedStore();
    await launchApp(tester, store);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dark'), 200);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(store.getString(StoreKeys.themeMode), 'dark');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
