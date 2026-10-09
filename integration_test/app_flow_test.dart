import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:resqmesh/app/app.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/identity/identity_repository.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/connection_manager.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/features/chat/data/drift_message_repository.dart';
import 'package:resqmesh/features/chat/data/messaging_service.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/file_transfer/data/drift_file_transfer_repository.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_engine.dart';
import 'package:resqmesh/features/file_transfer/data/file_picker_service.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:uuid/uuid.dart';

import '../test/support/fake_file_picker.dart';
import '../test/support/fake_notifications.dart';
import '../test/support/memory_key_value_store.dart';

/// P10.2 on a device: the real app (discovery, connections, the transfer
/// worker isolate, SQLite) talks to a second phone running in this test,
/// over the device's own Wi-Fi address.
final class Peer {
  Peer._(
    this.id,
    this.links,
    this.messages,
    this.repository,
    this.transfers,
    this.store,
  );

  static Future<Peer> start(Directory dir) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    final id = const Uuid().v4();
    SelfInfo self() => SelfInfo(
      deviceId: id,
      name: 'Device Peer',
      nameClaimedAt: DateTime.utc(2026),
      announce: true,
      appVersion: 'test',
    );
    final logger = AppLogger();
    final links = ConnectionManager(
      self: self,
      logger: logger,
      preferredPort: 0,
    );
    await links.start();
    final store = FileStore(dir);
    final transfers = TransferService(
      backend: TransferEngine(preferredPort: 0),
      repository: DriftFileTransferRepository(db),
      store: store,
      links: links,
      self: self,
      freeSpace: () async => 64 << 30,
      logger: logger,
    );
    await transfers.start();
    final repository = DriftMessageRepository(db);
    final messages = MessagingService(
      links: links,
      repository: repository,
      self: self,
      logger: logger,
      transfers: transfers,
    )..start();
    return Peer._(id, links, messages, repository, transfers, store);
  }

  final String id;
  final ConnectionManager links;
  final MessagingService messages;
  final DriftMessageRepository repository;
  final TransferService transfers;
  final FileStore store;
}

/// Pumps frames in real time until [finder] matches, then lets the page
/// finish sliding in so taps land where the widgets are.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 30,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) fail('never appeared: $finder');
    await tester.pump(const Duration(milliseconds: 200));
  }
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> until(
  WidgetTester tester,
  Future<bool> Function() check, {
  int seconds = 60,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!await check()) {
    if (DateTime.now().isAfter(end)) fail('condition never met');
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, then text both ways and a verified file', (
    tester,
  ) async {
    final temp = await Directory.systemTemp.createTemp('linkup_it');
    final store = MemoryKeyValueStore();
    final picker = FakeFilePicker();
    final container = ProviderContainer(
      overrides: [
        coreServicesProvider.overrideWith((ref) async {
          await IdentityRepository(store).ensureDeviceId();
          return CoreServices(store: store, supportDirectory: temp);
        }),
        appDatabaseProvider.overrideWithValue(
          AppDatabase(NativeDatabase.memory()),
        ),
        appNotificationsProvider.overrideWithValue(
          FakeNotifications(permitted: true),
        ),
        filePickerProvider.overrideWithValue(picker),
      ],
    );
    final peer = await Peer.start(
      await Directory(p.join(temp.path, 'peer')).create(),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ResQMeshApp(),
      ),
    );

    // Onboarding: welcome → name → how to connect → Home.
    await waitFor(tester, find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await waitFor(tester, find.text('Choose your name'));
    await tester.enterText(find.byType(TextField), 'Yusuf Device');
    await tester.tap(find.text('Continue'));
    await waitFor(
      tester,
      find.text('How do you want to connect?'),
      seconds: 15,
    );
    await tester.tap(find.text('Wi-Fi network'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start'));
    await waitFor(tester, find.text('Hi, Yusuf Device'));
    expect(store.getString(StoreKeys.username), 'Yusuf Device');

    // The peer dials the app on the device's own Wi-Fi address.
    final appId = store.getString(StoreKeys.deviceId)!;
    final links = container.read(peerLinksProvider);
    await until(tester, () async => links.current.listeningPort != null);
    final network = container.read(networkMonitorProvider).current;
    final address = network.interfaces.first.address;
    peer.links.updateEndpoints([
      PeerEndpoint(
        deviceId: appId,
        address: address,
        port: links.current.listeningPort!,
      ),
    ]);
    await until(
      tester,
      () async => peer.links.current.links.containsKey(appId),
    );

    // The app shows the peer and opens a chat with it.
    await tester.tap(find.text('People'));
    await waitFor(tester, find.text('Device Peer'));
    await tester.tap(find.text('Chat'));
    await waitFor(tester, find.text('Say hello to Device Peer'));

    // Text from the app to the peer, then a reply.
    await tester.enterText(find.byType(TextField).last, 'Hello from the app');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await until(tester, () async {
      final chat = await peer.repository.watchConversation(appId).first;
      return chat.any((m) => m.text == 'Hello from the app');
    });
    await peer.messages.sendText(
      peerId: appId,
      peerName: 'Yusuf Device',
      text: 'Hi back',
    );
    await waitFor(tester, find.text('Hi back'));
    await until(tester, () async {
      final chat = await peer.repository.watchConversation(appId).first;
      return chat.firstWhere((m) => m.isOutgoing).status.rank >=
          MessageStatus.delivered.rank;
    });

    // A 5 MB file from the app, through the worker isolate.
    final random = Random(1);
    final source = File(p.join(temp.path, 'pick', 'report.pdf'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(
      Uint8List.fromList(List.generate(5 << 20, (_) => random.nextInt(256))),
    );
    final expected = sha256.convert(await source.readAsBytes()).toString();
    picker.next = [
      PickedFile(path: source.path, name: 'report.pdf', size: 5 << 20),
    ];
    await tester.tap(find.byTooltip('Attach files'));
    await waitFor(tester, find.text('Send to Device Peer'));
    await tester.tap(find.text('Send'));
    await until(tester, () async {
      final files = await peer.repository.watchConversation(appId).first;
      final file = files.where((m) => m.isFile).firstOrNull;
      if (file == null) return false;
      final transfer = await peer.transfers.find(file.fileId!);
      return transfer?.status == TransferStatus.completed;
    });
    final got = (await peer.repository.watchConversation(appId).first)
        .firstWhere((m) => m.isFile);
    final transfer = (await peer.transfers.find(got.fileId!))!;
    final bytes = await peer.store.file(transfer.localPath!).readAsBytes();
    expect(sha256.convert(bytes).toString(), expected);
    await waitFor(tester, find.text('Sent'));

    await peer.messages.stop();
    await peer.transfers.stop();
    await peer.links.stop();
  });
}
