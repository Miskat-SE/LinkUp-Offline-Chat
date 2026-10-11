import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/network_monitor.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';
import 'package:resqmesh/features/file_transfer/data/engine/deferred_backend.dart';
import 'package:resqmesh/features/file_transfer/data/engine/transfer_backend.dart';

import '../../support/fake_transfer_backend.dart';

/// The Dart sides of the Kotlin bridge, with the Android side faked.
final class _Lan extends LanHostApi {
  final List<String> calls = [];
  LanSnapshot snapshot = LanSnapshot(
    wifiConnected: true,
    boundToWifi: true,
    interfaces: [
      LanInterfaceInfo(
        name: 'wlan0',
        address: '192.168.0.10',
        prefixLength: 24,
        kind: 'wifi',
      ),
      LanInterfaceInfo(
        name: 'ap0',
        address: '192.168.43.1',
        prefixLength: 24,
        kind: 'hotspot',
      ),
      LanInterfaceInfo(
        name: 'eth0',
        address: '10.0.0.2',
        prefixLength: 8,
        kind: 'other',
      ),
      LanInterfaceInfo(
        name: 'p2p-wlan0-0',
        address: '192.168.49.1',
        prefixLength: 24,
        kind: 'wifiDirect',
      ),
    ],
  );

  @override
  Future<void> startMonitoring() async => calls.add('start');

  @override
  Future<void> stopMonitoring() async {
    calls.add('stop');
    throw PlatformException(code: 'detached');
  }

  @override
  Future<LanSnapshot> currentSnapshot() async => snapshot;

  @override
  Future<void> acquireMulticastLock() async => calls.add('lock');

  @override
  Future<void> releaseMulticastLock() async => calls.add('unlock');

  @override
  Future<void> setBindToWifi(bool bind) async => calls.add('bind:$bind');
}

final class _P2p extends WifiDirectHostApi {
  final List<String> calls = [];
  String state = 'locationOff';

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<String> permissionState() async => state;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> openLocationSettings() async => calls.add('location');

  @override
  Future<void> start(String deviceId, String name) async =>
      calls.add('start:$name');

  @override
  Future<void> stop() async {
    calls.add('stop');
    throw PlatformException(code: 'detached');
  }

  @override
  Future<void> advertise(
    bool hosting,
    String? networkName,
    String? passphrase,
  ) async => calls.add('advertise:$hosting:$networkName');

  @override
  Future<void> createGroup(String networkName, String passphrase) async =>
      calls.add('create:$networkName');

  @override
  Future<void> joinGroup(
    String deviceAddress,
    String? networkName,
    String? passphrase,
  ) async => calls.add('join:$deviceAddress:$networkName');

  @override
  Future<void> leaveGroup() async => calls.add('leave');
}

final class _Notifications extends NotificationHostApi {
  bool fail = false;
  final List<String> calls = [];
  String? route = '/chat/abc';

  Future<T> _maybe<T>(String call, T value) async {
    calls.add(call);
    if (fail) throw PlatformException(code: 'no engine');
    return value;
  }

  @override
  Future<bool> notificationsAllowed() => _maybe('allowed', true);

  @override
  Future<bool> requestNotificationPermission() => _maybe('request', true);

  @override
  Future<void> showMessageNotification(MessageNotification n) =>
      _maybe('show ${n.conversationId} ${n.title}', null);

  @override
  Future<void> cancelConversation(String id) => _maybe('cancel $id', null);

  @override
  Future<String?> takeOpenedRoute() => _maybe('take', route);
}

final class _Background extends BackgroundHostApi {
  final List<BackgroundState> states = [];
  bool refuse = false;
  int opened = 0;

  @override
  Future<void> update(BackgroundState state) async {
    if (refuse) {
      throw PlatformException(code: 'ForegroundServiceStartNotAllowed');
    }
    states.add(state);
  }

  @override
  Future<void> openBatterySettings() async => opened++;
}

final class _Files extends FileHostApi {
  final List<String> calls = [];
  bool fail = false;

  @override
  Future<int> freeBytes() async {
    if (fail) throw PlatformException(code: 'x');
    return 123;
  }

  @override
  Future<bool> openFile(String path, String name, String mime) async {
    calls.add('open $name $mime');
    return true;
  }

  @override
  Future<void> shareFile(String path, String name, String mime) async =>
      calls.add('share $name');

  @override
  Future<String?> saveToDownloads(String path, String name, String mime) async {
    calls.add('save $name');
    return 'saved $name';
  }

  @override
  Future<bool> videoThumbnail(String path, String out) async {
    calls.add('thumb');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the network monitor maps the bridge snapshot and its updates',
    () async {
      final host = _Lan();
      final monitor = PlatformNetworkMonitor(host: host);
      final seen = <NetworkSnapshot>[];
      monitor.changes.listen(seen.add);
      await monitor.start();
      final now = monitor.current;
      expect(now.wifiConnected, isTrue);
      expect(now.boundToWifi, isTrue);
      expect(now.interfaces.map((i) => i.kind), [
        LanInterfaceKind.wifi,
        LanInterfaceKind.hotspot,
        LanInterfaceKind.other,
        LanInterfaceKind.wifiDirect,
      ]);
      expect(now.isHotspotHost, isTrue);
      expect(now.inWifiDirectGroup, isTrue);
      expect(now.broadcastTargets, contains('192.168.49.255'));
      expect(now.broadcastTargets, contains('192.168.43.255'));

      // Android reports a change; the same snapshot again is not repeated.
      monitor.onLanChanged(
        LanSnapshot(wifiConnected: false, boundToWifi: false, interfaces: []),
      );
      monitor.onLanChanged(
        LanSnapshot(wifiConnected: false, boundToWifi: false, interfaces: []),
      );
      await Future<void>.delayed(Duration.zero);
      expect(monitor.current.hasLan, isFalse);
      expect(seen.where((s) => !s.hasLan), hasLength(1));

      await monitor.setMulticastLock(held: true);
      await monitor.setMulticastLock(held: false);
      await monitor.setBindToWifi(bind: false);
      await monitor.stop(); // a detached engine is not an error
      expect(host.calls, ['start', 'lock', 'unlock', 'bind:false', 'stop']);
    },
  );

  test('Wi-Fi Direct goes through the bridge and maps its events', () async {
    final host = _P2p();
    final p2p = PlatformWifiDirect(host: host);
    expect(await p2p.isSupported(), isTrue);
    expect(await p2p.permission(), P2pPermission.locationOff);
    host.state = 'granted';
    expect(await p2p.permission(), P2pPermission.granted);
    host.state = 'denied';
    expect(await p2p.permission(), P2pPermission.denied);
    expect(await p2p.requestPermission(), isTrue);

    final found = <P2pPeer>[];
    final groups = <P2pGroup>[];
    p2p.found.listen(found.add);
    p2p.groups.listen(groups.add);
    p2p
      ..onServiceFound(
        WifiDirectService(
          deviceAddress: '02:00:00:00:00:01',
          deviceId: 'id-1',
          name: 'Rahim',
          hosting: true,
          networkName: 'DIRECT-LU-abcd',
          passphrase: 'pw',
        ),
      )
      ..onGroupChanged(
        WifiDirectGroup(
          enabled: true,
          formed: true,
          isOwner: true,
          clients: 2,
          networkName: 'DIRECT-LU-abcd',
        ),
      );
    await Future<void>.delayed(Duration.zero);
    expect(found.single.name, 'Rahim');
    expect(found.single.hosting, isTrue);
    expect(groups.single.clients, 2);

    await p2p.start(deviceId: 'me', name: 'Yusuf');
    await p2p.advertise(hosting: true, networkName: 'DIRECT-LU-me');
    await p2p.createGroup('DIRECT-LU-me', 'secret');
    await p2p.joinGroup(found.single);
    await p2p.leaveGroup();
    await p2p.openLocationSettings();
    await p2p.stop(); // a detached engine is not an error
    expect(host.calls, [
      'start:Yusuf',
      'advertise:true:DIRECT-LU-me',
      'create:DIRECT-LU-me',
      'join:02:00:00:00:00:01:DIRECT-LU-abcd',
      'leave',
      'location',
      'stop',
    ]);
  });

  test('notifications go through the bridge; failures are quiet', () async {
    final host = _Notifications();
    final notifications = PlatformNotifications(host: host);
    expect(await notifications.allowed(), isTrue);
    expect(await notifications.requestPermission(), isTrue);
    await notifications.showMessage(
      conversationId: 'abc',
      title: 'Rahim',
      body: 'Hi',
    );
    await notifications.cancelConversation('abc');
    expect(await notifications.takeOpenedRoute(), '/chat/abc');
    var opened = 0;
    notifications.opened.listen((_) => opened++);
    notifications.onNotificationOpened();
    await Future<void>.delayed(Duration.zero);
    expect(opened, 1);

    host.fail = true;
    expect(await notifications.allowed(), isFalse);
    expect(await notifications.takeOpenedRoute(), isNull);
    await notifications.showMessage(
      conversationId: 'abc',
      title: 'R',
      body: 'b',
    );
    expect(host.calls.first, 'allowed');
    expect(host.calls, contains('show abc Rahim'));
  });

  test(
    'the background service forwards states; a refusal is not an error',
    () async {
      final host = _Background();
      final service = PlatformBackgroundService(host);
      final state = BackgroundState(
        transferring: true,
        stayReachable: false,
        title: 't',
        text: 'x',
        progress: 5,
      );
      await service.update(state);
      host.refuse = true;
      await service.update(state); // app not visible: skipped quietly
      await service.openBatterySettings();
      expect(host.states, hasLength(1));
      expect(host.opened, 1);
    },
  );

  test('file actions go through the bridge', () async {
    final host = _Files();
    final files = PlatformFileActions(host);
    expect(await files.freeBytes(), 123);
    expect(
      await files.open('/p', name: 'a.pdf', mimeType: 'application/pdf'),
      isTrue,
    );
    await files.share('/p', name: 'a.pdf', mimeType: 'application/pdf');
    expect(
      await files.saveToDownloads(
        '/p',
        name: 'a.pdf',
        mimeType: 'application/pdf',
      ),
      'saved a.pdf',
    );
    expect(await files.videoThumbnail('/v', '/t'), isTrue);
    host.fail = true;
    expect(await files.freeBytes(), isNull);
    expect(host.calls, [
      'open a.pdf application/pdf',
      'share a.pdf',
      'save a.pdf',
      'thumb',
    ]);
  });

  test(
    'the deferred backend waits for the worker, then passes everything on',
    () async {
      final real = FakeTransferBackend();
      final deferred = DeferredTransferBackend(
        Future<TransferBackend>.delayed(
          const Duration(milliseconds: 20),
          () => real,
        ),
      );
      final events = <TransferEvent>[];
      deferred.events.listen(events.add);
      expect(
        await deferred.start(
          TransferIdentity(
            deviceId: 'a',
            name: 'Yusuf',
            nameClaimedAt: DateTime.utc(2026),
            appVersion: '1',
          ),
        ),
        28762,
      );
      deferred
        ..upload(
          const UploadRequest(
            fileId: 'f',
            chatMessageId: 'm',
            peerId: 'p',
            address: '1.2.3.4',
            port: 1,
            path: '/x',
            fileName: 'x',
            fileSize: 1,
            mimeType: 'x',
            sha256: 's',
          ),
        )
        ..answer('f', const AlreadyHaveFile())
        ..stop('f', FileCancelReason.paused)
        ..updateIdentity(
          TransferIdentity(
            deviceId: 'a',
            name: 'Yusuf Ali',
            nameClaimedAt: DateTime.utc(2026),
            appVersion: '1',
          ),
        );
      expect(await deferred.hashFile('/x'), real.hash);
      expect(await deferred.reset(), 28762);
      real.emit(const TransferStarted('f', offset: 0));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(real.uploads.single.fileId, 'f');
      expect(real.answers['f'], isA<AlreadyHaveFile>());
      expect(real.stops.single.$1, 'f');
      expect(real.identity!.name, 'Yusuf Ali');
      expect(events.single, isA<TransferStarted>());
      await deferred.dispose();
    },
  );
}
