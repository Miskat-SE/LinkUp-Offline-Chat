import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/presentation/activity_screen.dart';
import 'package:resqmesh/features/file_transfer/presentation/transfer_details_screen.dart';

import '../../support/fake_background_service.dart';
import '../../support/fake_network_monitor.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_peer_links.dart';
import '../../support/fake_transfer_backend.dart';
import '../../support/memory_datagram_network.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

const fileId = '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80';
const sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

Future<void> work(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('Stay reachable is offered once and starts the service', (
    tester,
  ) async {
    final background = FakeBackgroundService();
    final store = onboarded(stayReachableOffered: false);
    await launchApp(tester, store, background: background, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Stay reachable when LinkUp is closed?'), findsOneWidget);
    expect(background.running, isFalse);

    await tester.tap(find.text('Turn on'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(store.getString(StoreKeys.stayReachable), 'on');
    expect(find.text('Stay reachable when LinkUp is closed?'), findsNothing);
    expect(background.running, isTrue);
    expect(background.last!.title, 'LinkUp is reachable');
    await closeApp(tester);

    // Not offered again.
    await launchApp(tester, store, background: background, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Stay reachable when LinkUp is closed?'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('Settings: switch Stay reachable off; battery settings', (
    tester,
  ) async {
    final background = FakeBackgroundService();
    final store = onboarded()..values[StoreKeys.stayReachable] = 'on';
    await launchApp(tester, store, background: background, settle: false);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(background.running, isTrue);

    await tester.tap(find.text('Settings'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Stay reachable'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(store.getString(StoreKeys.stayReachable), 'off');
    expect(background.running, isFalse);

    await tester.scrollUntilVisible(
      find.text('Battery settings'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Battery settings'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(background.batterySettingsOpened, 1);
    await closeApp(tester);
  });

  testWidgets('a transfer shows in Activity; its notification opens details', (
    tester,
  ) async {
    final lan = MemoryDatagramNetwork();
    final rahim = await startOtherPhone(lan, name: 'Rahim');
    final links = FakePeerLinks();
    final transfers = FakeTransferBackend();
    final notifications = FakeNotifications(permitted: true);
    final background = FakeBackgroundService();
    final store = onboarded();
    await launchApp(
      tester,
      store,
      lan: lan,
      links: links,
      transfers: transfers,
      notifications: notifications,
      background: background,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    await work(tester);

    final myId = store.getString(StoreKeys.deviceId)!;
    PacketHeader header() => PacketHeader.create(
      senderId: otherPhoneId,
      senderName: 'Rahim',
      receiverId: myId,
    );
    links.receive(
      otherPhoneId,
      MessagePacket(
        header(),
        kind: MessageKind.file,
        audience: MessageAudience.direct,
        file: const FileRef(
          fileId: fileId,
          name: 'video.mp4',
          size: 1000,
          mimeType: 'video/mp4',
          sha256: sha,
        ),
      ),
    );
    await work(tester);
    transfers.emit(
      OfferReceived(
        FileOfferPacket(
          header(),
          fileId: fileId,
          chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
          fileName: 'video.mp4',
          fileSize: 1000,
          mimeType: 'video/mp4',
          sha256: sha,
        ),
        peerId: otherPhoneId,
      ),
    );
    await work(tester);
    transfers
      ..emit(const TransferStarted(fileId, offset: 0))
      ..emit(const TransferProgressed(fileId, bytes: 620));
    await work(tester);
    await pumpFor(tester, const Duration(milliseconds: 1200));
    await work(tester);
    expect(background.last!.transferring, isTrue);
    expect(background.last!.title, 'Receiving video.mp4 — 62%');
    expect(background.last!.route, '/files/$fileId/details');

    await tester.tap(find.byTooltip('Transfers'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    expect(find.text('video.mp4'), findsOneWidget);
    expect(find.textContaining('From Rahim'), findsOneWidget);

    // Tapping the service notification opens the transfer.
    notifications.tapRoute(background.last!.route!);
    await work(tester);
    expect(find.byType(TransferDetailsScreen), findsOneWidget);

    await rahim.stop();
    await closeApp(tester);
  });
}
