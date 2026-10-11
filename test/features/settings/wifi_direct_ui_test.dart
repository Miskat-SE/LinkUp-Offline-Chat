import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

import '../../support/fake_network_monitor.dart';
import '../../support/fake_wifi_direct.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

Future<MemoryKeyValueStore> wifiDirectPhone() async {
  final store = onboarded();
  await store.setString(StoreKeys.connectionMethod, 'wifiDirect');
  return store;
}

void main() {
  testWidgets('Wi-Fi Direct mode: unbound from Wi-Fi, looking for phones', (
    tester,
  ) async {
    final p2p = FakeWifiDirect();
    final network = FakeNetworkMonitor();
    await launchApp(
      tester,
      await wifiDirectPhone(),
      wifiDirect: p2p,
      network: network,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Wi-Fi Direct'), findsOneWidget);
    expect(find.text('Looking for phones nearby…'), findsOneWidget);
    expect(network.boundToWifi, isFalse);
    expect(p2p.starts.single.name, 'Yusuf');

    // Someone with a lower ID hosts: this phone joins.
    p2p
      ..group(P2pGroup.unknown)
      ..see(
        const P2pPeer(
          deviceAddress: '02:00:00:00:00:01',
          deviceId: '00000000-0000-4000-8000-000000000001',
          name: 'Rahim',
          hosting: true,
          networkName: 'DIRECT-LU-0000',
          passphrase: 'secret-pass',
        ),
      );
    await pumpFor(tester, const Duration(seconds: 4));
    expect(p2p.calls, contains('join:Rahim'));
    expect(find.text('Joining Rahim…'), findsOneWidget);
    p2p.group(const P2pGroup(enabled: true, formed: true));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Joined Rahim, connecting…'), findsOneWidget);

    // People explains Wi-Fi Direct, not routers.
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(
      find.textContaining('with Wi-Fi Direct will appear'),
      findsOneWidget,
    );
    await closeApp(tester);
  });

  testWidgets('permission: asked once, then an Allow button', (tester) async {
    final p2p = FakeWifiDirect()
      ..permissionState = P2pPermission.denied
      ..grantOnRequest = false;
    final store = await wifiDirectPhone();
    await launchApp(tester, store, wifiDirect: p2p, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(p2p.calls.where((c) => c == 'request'), hasLength(1));
    expect(store.getString(StoreKeys.wifiDirectAsked), 'yes');
    expect(
      find.text('LinkUp needs permission to find nearby phones'),
      findsOneWidget,
    );

    p2p.grantOnRequest = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Looking for phones nearby…'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Allow'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('Location off (Android 12 and older) offers its settings', (
    tester,
  ) async {
    final p2p = FakeWifiDirect()..permissionState = P2pPermission.locationOff;
    await launchApp(
      tester,
      await wifiDirectPhone(),
      wifiDirect: p2p,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Turn on Location to find nearby phones'), findsOneWidget);
    expect(
      find.textContaining('never uses or stores your location'),
      findsOneWidget,
    );
    await tester.tap(find.text('Turn on Location'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(p2p.calls, contains('location'));
    await closeApp(tester);
  });

  testWidgets('switching back to Wi-Fi network stops Wi-Fi Direct', (
    tester,
  ) async {
    final p2p = FakeWifiDirect();
    final network = FakeNetworkMonitor();
    final store = await wifiDirectPhone();
    await launchApp(
      tester,
      store,
      wifiDirect: p2p,
      network: network,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Change how you connect'));
    await pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Wi-Fi network'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Save'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(p2p.calls, contains('stop'));
    expect(network.boundToWifi, isTrue);
    await closeApp(tester);
  });
}
