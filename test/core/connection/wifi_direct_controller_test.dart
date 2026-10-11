import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/connection/wifi_direct_controller.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';

import '../../support/fake_wifi_direct.dart';

const a = 'aaaaaaaa-0000-4000-8000-000000000001';
const b = 'bbbbbbbb-0000-4000-8000-000000000002';
const c = 'cccccccc-0000-4000-8000-000000000003';

P2pPeer phone(String id, String name, {bool hosting = false}) => P2pPeer(
  deviceAddress: '02:00:00:00:00:${id.substring(0, 2)}',
  deviceId: id,
  name: name,
  hosting: hosting,
  networkName: hosting ? 'DIRECT-LU-${id.substring(0, 4)}' : null,
  passphrase: hosting ? 'secret-pass' : null,
);

const notInGroup = P2pGroup.unknown;
const hostingAlone = P2pGroup(
  enabled: true,
  formed: true,
  isOwner: true,
  networkName: 'DIRECT-LU-aaaa',
  passphrase: 'pw-from-android',
);

/// A controller for the phone with [self], on fake time.
void run(
  String self,
  void Function(
    FakeAsync async,
    FakeWifiDirect platform,
    WifiDirectController c,
  )
  body, {
  FakeWifiDirect? platform,
}) {
  fakeAsync((async) {
    final p = platform ?? FakeWifiDirect();
    final controller = WifiDirectController(
      platform: p,
      self: () => (deviceId: self, name: 'Me'),
      logger: AppLogger(),
    );
    controller.start();
    async.flushMicrotasks();
    p.group(notInGroup);
    async.flushMicrotasks();
    body(async, p, controller);
    controller.stop();
    async.flushMicrotasks();
  });
}

void main() {
  test('a phone without Wi-Fi Direct says so and starts nothing', () {
    run(a, (async, p, c) {
      expect(c.current.phase, WifiDirectPhase.unsupported);
      expect(p.calls, isEmpty);
    }, platform: FakeWifiDirect()..supported = false);
  });

  test('without permission it waits, then starts once allowed', () {
    final p = FakeWifiDirect()..permissionState = P2pPermission.denied;
    run(a, (async, p, c) {
      expect(c.current.phase, WifiDirectPhase.needsPermission);
      c.requestPermission();
      async.flushMicrotasks();
      expect(p.calls, containsAllInOrder(['start', 'request', 'start']));
      expect(c.current.phase, WifiDirectPhase.searching);
    }, platform: p);
  });

  test('Location off and Wi-Fi off are reported', () {
    final p = FakeWifiDirect()..permissionState = P2pPermission.locationOff;
    run(a, (async, p, c) {
      expect(c.current.phase, WifiDirectPhase.locationOff);
      p.permissionState = P2pPermission.granted;
      async.elapse(WifiDirectController.tickInterval);
      expect(c.current.phase, WifiDirectPhase.searching);
      p.group(const P2pGroup(enabled: false, formed: false));
      async.flushMicrotasks();
      expect(c.current.phase, WifiDirectPhase.wifiOff);
    }, platform: p);
  });

  test('the lowest ID hosts; it advertises the group credentials', () {
    run(a, (async, p, c) {
      p.see(phone(b, 'Rahim'));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls, contains('create'));
      expect(p.created!.networkName, 'DIRECT-LU-aaaa');
      expect(p.created!.passphrase, hasLength(16));
      expect(c.current.phase, WifiDirectPhase.connecting);

      p.group(hostingAlone);
      async.flushMicrotasks();
      expect(c.current.phase, WifiDirectPhase.hosting);
      // Android's own credentials win (Android 8–9 choose them).
      expect(p.advertised, (
        hosting: true,
        networkName: 'DIRECT-LU-aaaa',
        passphrase: 'pw-from-android',
      ));
    });
  });

  test('a higher ID waits for the host, then joins it', () {
    run(c, (async, p, ctl) {
      p.see(phone(b, 'Rahim'));
      async.elapse(const Duration(seconds: 10));
      expect(p.calls, isNot(contains('create')));
      expect(ctl.current.phase, WifiDirectPhase.searching);
      expect(ctl.current.nearby, 1);

      p.see(phone(b, 'Rahim', hosting: true));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls, contains('join:Rahim'));
      expect(ctl.current.phase, WifiDirectPhase.connecting);
      expect(ctl.current.hostName, 'Rahim');

      p.group(const P2pGroup(enabled: true, formed: true));
      async.flushMicrotasks();
      expect(ctl.current.phase, WifiDirectPhase.joined);
      expect(ctl.current.hostName, 'Rahim');
    });
  });

  test('with several hosts it joins the lowest ID', () {
    run(c, (async, p, ctl) {
      p
        ..see(phone(b, 'Rahim', hosting: true))
        ..see(phone(a, 'Karim', hosting: true));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls.where((x) => x.startsWith('join')).last, 'join:Karim');
    });
  });

  test('a join that never forms is retried with another host later', () {
    run(c, (async, p, ctl) {
      p.see(phone(a, 'Karim', hosting: true));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls.where((x) => x == 'join:Karim'), hasLength(1));
      // Keep Karim visible, but the group never forms.
      for (var i = 0; i < 20; i++) {
        async.elapse(const Duration(seconds: 3));
        p.see(phone(a, 'Karim', hosting: true));
      }
      // Timed out after 30 s, then Karim is skipped for a minute.
      expect(p.calls.where((x) => x == 'join:Karim'), hasLength(1));
      for (var i = 0; i < 20; i++) {
        async.elapse(const Duration(seconds: 3));
        p.see(phone(a, 'Karim', hosting: true));
      }
      expect(p.calls.where((x) => x == 'join:Karim'), hasLength(2));
    });
  });

  test('a refused join or create goes back to searching', () {
    final p = FakeWifiDirect()..refuseWith = 'busy';
    run(a, (async, p, c) {
      p.see(phone(b, 'Rahim'));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls, contains('create'));
      expect(c.current.phase, WifiDirectPhase.searching);
    }, platform: p);
  });

  test('a host nobody joined gives way to a lower host', () {
    run(b, (async, p, c) {
      p
        ..group(hostingAlone)
        ..see(phone(a, 'Karim', hosting: true));
      async.elapse(WifiDirectController.tickInterval);
      expect(p.calls, contains('leave'));
    });
  });

  test('a host with phones joined stays', () {
    run(b, (async, p, c) {
      p
        ..group(
          const P2pGroup(
            enabled: true,
            formed: true,
            isOwner: true,
            clients: 1,
          ),
        )
        ..see(phone(a, 'Karim', hosting: true));
      async.elapse(const Duration(minutes: 10));
      expect(p.calls, isNot(contains('leave')));
      expect(c.current.clients, 1);
    });
  });

  test('a host alone for 5 minutes with nobody around stops hosting', () {
    run(a, (async, p, c) {
      p.group(hostingAlone);
      async.elapse(const Duration(minutes: 4));
      expect(p.calls, isNot(contains('leave')));
      async.elapse(const Duration(minutes: 2));
      expect(p.calls, contains('leave'));
    });
  });

  test('phones not heard from for a minute are forgotten', () {
    run(c, (async, p, ctl) {
      p.see(phone(b, 'Rahim'));
      async.flushMicrotasks();
      expect(ctl.current.nearby, 1);
      async.elapse(const Duration(seconds: 70));
      expect(ctl.current.nearby, 0);
    });
  });

  test('a new name is advertised; stop leaves', () {
    run(a, (async, p, c) {
      c.nameChanged();
      async.flushMicrotasks();
      expect(p.starts, hasLength(2));
    });
  });
}
