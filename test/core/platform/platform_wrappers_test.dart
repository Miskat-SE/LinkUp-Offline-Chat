import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/network_monitor.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';
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
      ]);
      expect(now.isHotspotHost, isTrue);
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
      await monitor.stop(); // a detached engine is not an error
      expect(host.calls, ['start', 'lock', 'unlock', 'stop']);
    },
  );

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
