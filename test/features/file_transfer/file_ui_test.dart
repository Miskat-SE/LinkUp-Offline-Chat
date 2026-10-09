import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_message_card.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_preview_screen.dart';
import 'package:resqmesh/features/file_transfer/presentation/transfer_details_screen.dart';

import '../../support/fake_file_actions.dart';
import '../../support/fake_file_picker.dart';
import '../../support/fake_network_monitor.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_peer_links.dart';
import '../../support/fake_transfer_backend.dart';
import '../../support/memory_datagram_network.dart';
import '../../support/memory_key_value_store.dart';
import '../../support/other_phone.dart';
import '../../support/test_app.dart';

const sha = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const fileId = '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80';

/// Yusuf's app with Rahim connected; files go through fakes.
final class FileScenario {
  FileScenario._(
    this.store,
    this.links,
    this.transfers,
    this.files,
    this.picker,
    this.support,
  );

  static Future<FileScenario> start(WidgetTester tester) async {
    final lan = MemoryDatagramNetwork();
    final rahim = await startOtherPhone(lan, name: 'Rahim');
    final links = FakePeerLinks();
    final transfers = FakeTransferBackend();
    final files = FakeFileActions();
    final picker = FakeFilePicker();
    final store = onboarded();
    final support = Directory.systemTemp.createTempSync('resqmesh_ui');
    addTearDown(() => support.deleteSync(recursive: true));
    await launchApp(
      tester,
      store,
      lan: lan,
      links: links,
      transfers: transfers,
      fileActions: files,
      picker: picker,
      notifications: FakeNotifications(permitted: true),
      supportDirectory: support,
      network: FakeNetworkMonitor.onWifi('192.168.0.10'),
      settle: false,
    );
    await pumpFor(tester, const Duration(seconds: 1));
    final scenario = FileScenario._(
      store,
      links,
      transfers,
      files,
      picker,
      support,
    ).._rahim = rahim;
    await scenario.work(tester); // file storage set up
    return scenario;
  }

  final MemoryKeyValueStore store;
  final FakePeerLinks links;
  final FakeTransferBackend transfers;
  final FakeFileActions files;
  final FakeFilePicker picker;
  final Directory support;
  late final DiscoveryEngine _rahim;

  String get myId => store.getString(StoreKeys.deviceId)!;

  /// Real file work (moving, measuring, listing) needs real time; each
  /// step completes in real time and then continues on the next frame.
  Future<void> work(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openChat(WidgetTester tester) async {
    await tester.tap(find.text('People'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Chat'));
    await pumpFor(tester, const Duration(seconds: 1));
  }

  PickedFile cacheFile(String name, String content) {
    final file = File(p.join(support.path, 'cache', name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return PickedFile(path: file.path, name: name, size: content.length);
  }

  /// Rahim sends Yusuf a file MESSAGE.
  void rahimSendsFile({String name = 'trip.jpg', int size = 2048}) =>
      links.receive(
        otherPhoneId,
        MessagePacket(
          PacketHeader.create(
            senderId: otherPhoneId,
            senderName: 'Rahim',
            receiverId: myId,
          ),
          kind: MessageKind.file,
          audience: MessageAudience.direct,
          file: FileRef(
            fileId: fileId,
            name: name,
            size: size,
            mimeType: 'image/jpeg',
            sha256: sha,
          ),
        ),
      );

  /// Rahim's engine offers the file to Yusuf's.
  void rahimOffers({int size = 2048}) => transfers.emit(
    OfferReceived(
      FileOfferPacket(
        PacketHeader.create(
          senderId: otherPhoneId,
          senderName: 'Rahim',
          receiverId: myId,
        ),
        fileId: fileId,
        chatMessageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
        fileName: 'trip.jpg',
        fileSize: size,
        mimeType: 'image/jpeg',
        sha256: sha,
      ),
      peerId: otherPhoneId,
    ),
  );

  Future<void> finish(WidgetTester tester) async {
    await _rahim.stop();
    await closeApp(tester);
  }
}

void main() {
  testWidgets('attach: pick, review, remove one, send', (tester) async {
    final s = await FileScenario.start(tester);
    await s.openChat(tester);
    s.picker.next = [
      s.cacheFile('report.pdf', 'pdf bytes'),
      s.cacheFile('song.mp3', 'mp3 bytes'),
    ];

    await tester.tap(find.byTooltip('Attach files'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Send to Rahim'), findsOneWidget);
    expect(find.text('Send 2 files'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove').last);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.text('song.mp3'), findsNothing);
    await tester.tap(find.text('Send'));
    await s.work(tester);
    await s.work(tester);

    expect(find.byType(FileMessageCard), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    // Hashed and announced; the MESSAGE carries the file.
    final packet = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    expect(packet.kind, MessageKind.file);
    expect(packet.file!.name, 'report.pdf');

    // Rahim confirms: the data starts.
    s.links.receive(
      otherPhoneId,
      MessageAckPacket(
        PacketHeader.create(
          senderId: otherPhoneId,
          senderName: 'Rahim',
          receiverId: s.myId,
        ),
        ackFor: packet.header.messageId,
      ),
    );
    await s.work(tester);
    expect(s.transfers.uploads.single.fileName, 'report.pdf');
    final id = s.transfers.uploads.single.fileId;
    s.transfers
      ..emit(TransferStarted(id, offset: 0))
      ..emit(TransferProgressed(id, bytes: 4));
    await s.work(tester);
    expect(find.textContaining('Sending 44%'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    s.transfers.emit(TransferEnded(id, const TransferCompleted()));
    await s.work(tester);
    expect(find.text('Sent'), findsOneWidget);
    await s.finish(tester);
  });

  testWidgets('a received file shows progress, then opens in the preview', (
    tester,
  ) async {
    final s = await FileScenario.start(tester);
    s.rahimSendsFile();
    await s.work(tester);
    // The chat list names the file.
    expect(find.text('📎 trip.jpg'), findsOneWidget);
    await s.openChat(tester);
    expect(find.text('trip.jpg'), findsOneWidget);
    expect(find.text('Waiting for Rahim'), findsOneWidget);

    s.rahimOffers();
    await s.work(tester);
    expect(s.transfers.answers[fileId], isA<AcceptOffer>());
    s.transfers
      ..emit(const TransferStarted(fileId, offset: 0))
      ..emit(const TransferProgressed(fileId, bytes: 1024));
    await s.work(tester);
    expect(find.textContaining('Receiving 50%'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);

    // The engine wrote the file into received/.
    File(p.join(s.support.path, 'files', 'received', fileId))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(2048, 1));
    s.transfers.emit(const TransferEnded(fileId, TransferCompleted()));
    await s.work(tester);
    expect(find.text('Received'), findsOneWidget);

    await tester.tap(find.text('trip.jpg'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(FilePreviewScreen), findsOneWidget);
    await tester.tap(find.text('Open'));
    await s.work(tester);
    expect(s.files.opened, ['trip.jpg']);
    await tester.tap(find.byTooltip('Share'));
    await s.work(tester);
    expect(s.files.shared, ['trip.jpg']);
    await tester.tap(find.byTooltip('Save to Downloads'));
    await s.work(tester);
    expect(s.files.saved, ['trip.jpg']);
    expect(find.text('Saved to Downloads as “trip.jpg”'), findsOneWidget);
    await s.finish(tester);
  });

  testWidgets('details show live numbers and pause a file being sent', (
    tester,
  ) async {
    final s = await FileScenario.start(tester);
    await s.openChat(tester);
    s.picker.next = [s.cacheFile('movie.mp4', 'x' * 1000)];
    await tester.tap(find.byTooltip('Attach files'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Send'));
    await s.work(tester);
    await s.work(tester);
    final packet = s.links.sent
        .map((e) => e.$2)
        .whereType<MessagePacket>()
        .single;
    s.links.receive(
      otherPhoneId,
      MessageDeliveredPacket(
        PacketHeader.create(
          senderId: otherPhoneId,
          senderName: 'Rahim',
          receiverId: s.myId,
        ),
        messageIds: [packet.header.messageId],
      ),
    );
    await s.work(tester);
    final id = s.transfers.uploads.single.fileId;
    s.transfers
      ..emit(TransferStarted(id, offset: 0))
      ..emit(TransferProgressed(id, bytes: 250));
    await s.work(tester);

    await tester.tap(find.text('movie.mp4'));
    await pumpFor(tester, const Duration(seconds: 1));
    expect(find.byType(TransferDetailsScreen), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('250 B of 1000 B'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await s.work(tester);
    expect(s.transfers.stops.single, (id, FileCancelReason.paused));
    await s.finish(tester);
  });

  testWidgets('Storage: clear all local data starts again at onboarding', (
    tester,
  ) async {
    final s = await FileScenario.start(tester);
    s.rahimSendsFile();
    await s.work(tester);
    await tester.tap(find.text('Settings'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
      find.text('1 message'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Centred, clear of the pinned title bar and the tab bar.
    await Scrollable.ensureVisible(
      tester.element(find.text('1 message')),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(find.text('1 message'));
    // Measuring folders is real file work.
    for (
      var i = 0;
      i < 10 && find.text('Files received').evaluate().isEmpty;
      i++
    ) {
      await s.work(tester);
    }
    expect(find.text('Files received'), findsOneWidget);
    expect(find.text('Copies of sent files'), findsOneWidget);

    await tester.tap(find.text('Clear all local data'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Clear all local data?'), findsOneWidget);
    await tester.tap(find.text('Clear everything'));
    for (
      var i = 0;
      i < 10 && find.byType(ChatScreen).evaluate().isNotEmpty;
      i++
    ) {
      await s.work(tester);
    }
    for (var i = 0; i < 4; i++) {
      await s.work(tester);
    }
    await pumpFor(tester, const Duration(seconds: 2));

    expect(find.byType(ChatScreen), findsNothing);
    expect(s.store.getString(StoreKeys.username), isNull);
    expect(find.textContaining('LinkUp'), findsWidgets, reason: 'welcome');
    await s.finish(tester);
  });
}
