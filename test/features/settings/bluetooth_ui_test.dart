import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

import '../../support/fake_bluetooth.dart';
import '../../support/fake_peer_links.dart';
import '../../support/fake_transfer_backend.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

Future<MemoryKeyValueStore> bluetoothPhone() async {
  final store = onboarded();
  await store.setString(StoreKeys.connectionMethod, 'bluetooth');
  return store;
}

void main() {
  testWidgets('Bluetooth mode: advertises and looks for phones', (
    tester,
  ) async {
    final bt = FakeBluetooth();
    final store = await bluetoothPhone();
    await launchApp(tester, store, bluetooth: bt, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Looking for phones nearby…'), findsOneWidget);
    expect(bt.advertising?.deviceId, store.getString(StoreKeys.deviceId));
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.textContaining('with Bluetooth will appear'), findsOneWidget);
    await tester.tap(find.text('Chats'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    bt.see(
      const BtFound(
        address: 'BB:01',
        deviceId: 'bbbbbbbb-0000-4000-8000-000000000002',
        channel: 0x85,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));
    // The (stand-in) connection comes up at once: connected by Bluetooth.
    expect(find.text('Connected by Bluetooth · 1 nearby'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('Bluetooth off offers to turn it on', (tester) async {
    final bt = FakeBluetooth()..enabled = false;
    await launchApp(
      tester,
      await bluetoothPhone(),
      bluetooth: bt,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    // ignore: avoid_print
    print(
      'DBG ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).where((t) => t != null).take(8).toList()} ${bt.calls}',
    );
    expect(find.text('Bluetooth is off'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Turn on Bluetooth'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(bt.calls, contains('enable'));
    bt.setEnabled(true);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Looking for phones nearby…'), findsOneWidget);
    expect(bt.advertising, isNotNull, reason: 'server opened once on');
    await closeApp(tester);
  });

  testWidgets('permission: asked once, then an Allow button', (tester) async {
    final bt = FakeBluetooth()
      ..permissionState = BtPermission.denied
      ..grantOnRequest = false;
    final store = await bluetoothPhone();
    await launchApp(tester, store, bluetooth: bt, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(bt.calls.where((c) => c == 'request'), hasLength(1));
    expect(store.getString(StoreKeys.bluetoothAsked), 'yes');
    expect(
      find.text('LinkUp needs permission to find nearby phones'),
      findsOneWidget,
    );
    bt.grantOnRequest = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Looking for phones nearby…'), findsOneWidget);
    expect(bt.advertising, isNotNull);
    await closeApp(tester);
  });

  testWidgets('file channel opens once allowed, and again after Bluetooth '
      'is turned off and on', (tester) async {
    final bt = FakeBluetooth()
      ..permissionState = BtPermission.denied
      ..grantOnRequest = false;
    // Like the Bluetooth engine: no file channel without permission.
    final transfers = FakeTransferBackend()..port = null;
    final links = FakePeerLinks();
    await launchApp(
      tester,
      await bluetoothPhone(),
      bluetooth: bt,
      transfers: transfers,
      links: links,
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    expect(links.filePort, isNull);

    bt.grantOnRequest = true;
    transfers.port = 0x83;
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(transfers.resets, 1);
    expect(links.filePort, 0x83, reason: 'others can now send files');

    transfers.port = 0x85;
    bt.setEnabled(false);
    await pumpFor(tester, const Duration(milliseconds: 500));
    bt.setEnabled(true);
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(transfers.resets, 2);
    expect(links.filePort, 0x85);
    await closeApp(tester);
  });
}
