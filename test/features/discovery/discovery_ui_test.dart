import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/shared/widgets/name_form.dart';

import '../../support/fake_network_monitor.dart';
import '../../support/fake_peer_links.dart';
import '../../support/memory_datagram_network.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

void main() {
  testWidgets('Home and People show a phone found on the same Wi-Fi', (
    tester,
  ) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(lan, name: 'Rahim');
    await launchApp(
      tester,
      onboarded(),
      lan: lan,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 2));

    expect(find.text('Local network connected · 1 nearby'), findsOneWidget);

    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Online · 1'), findsOneWidget);
    expect(find.text('Rahim'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    await finish(tester, other);
  });

  testWidgets('a phone that leaves is shown as seen earlier', (tester) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(lan, name: 'Rahim');
    await launchApp(
      tester,
      onboarded(),
      lan: lan,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(seconds: 2));
    expect(find.text('Online · 1'), findsOneWidget);

    await other.stop(); // says GOODBYE
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Seen earlier'), findsOneWidget);
    expect(find.text('Last seen just now'), findsOneWidget);
    await finish(tester, other);
  });

  testWidgets('a phone that is found but cannot be reached says so', (
    tester,
  ) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(lan, name: 'Rahim');
    final links = FakePeerLinks()..refused.add(other.self.deviceId);
    await launchApp(
      tester,
      onboarded(),
      lan: lan,
      links: links,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 2));

    expect(find.text("Found Rahim, but couldn't connect"), findsOneWidget);
    expect(
      find.text('The router may be blocking device-to-device traffic.'),
      findsOneWidget,
    );
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text("Can't connect"), findsOneWidget);
    await finish(tester, other);
  });

  testWidgets('without Wi-Fi the status says so', (tester) async {
    await launchApp(tester, onboarded());

    expect(find.text('Wi-Fi disconnected'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('onboarding refuses a name already used on the network', (
    tester,
  ) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(lan, name: 'Yusuf');
    final store = MemoryKeyValueStore();
    await launchApp(
      tester,
      store,
      lan: lan,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );

    await tester.tap(find.text('Get started'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'yusuf');
    await tester.tap(find.text('Continue'));
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.text(nameTakenMessage), findsOneWidget);
    expect(store.getString(StoreKeys.username), isNull);

    await tester.enterText(find.byType(TextField), 'Karim');
    await tester.tap(find.text('Continue'));
    // A free name is confirmed after nobody objects for 3 s.
    await pumpFor(tester, const Duration(seconds: 4));
    expect(store.getString(StoreKeys.username), 'Karim');
    expect(find.text('How do you want to connect?'), findsOneWidget);
    await finish(tester, other);
  });

  testWidgets('a later name clash shows a banner on Home', (tester) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(
      lan,
      name: 'Yusuf',
      claimedAt: DateTime.utc(2026),
    );
    await launchApp(
      tester,
      onboarded(claimedAt: DateTime.utc(2026, 10)),
      lan: lan,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 2));

    expect(
      find.text('Your name is also used by another device on this network.'),
      findsOneWidget,
    );
    await finish(tester, other);
  });

  testWidgets('the developer screen shows ports, peers and packets', (
    tester,
  ) async {
    final lan = MemoryDatagramNetwork();
    final other = await startOtherPhone(lan, name: 'Rahim');
    await launchApp(
      tester,
      onboarded(),
      lan: lan,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await tester.tap(find.text('Settings'));
    await pumpFor(tester, const Duration(seconds: 1));
    // Debug builds (and tests) always have developer mode.
    // Bring the row to the top, clear of the bottom navigation bar.
    await tester.ensureVisible(find.text('Developer options'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Developer options'));
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.text('listening on 28760'), findsOneWidget);
    expect(find.textContaining('192.168.0.10/24'), findsOneWidget);
    expect(find.textContaining('Rahim · bbbb'), findsOneWidget);
    await finish(tester, other);
  });
}
