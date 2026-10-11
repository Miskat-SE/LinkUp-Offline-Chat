import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/connection/wifi_direct_controller.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';

import '../../support/fake_wifi_direct.dart';

const a = 'aaaaaaaa-0000-4000-8000-000000000001';
const b = 'bbbbbbbb-0000-4000-8000-000000000002';
const c = 'cccccccc-0000-4000-8000-000000000003';

/// A LinkUp phone with [id] that has seen the phones in [seen].
P2pPeer phone(String id, String name, {List<String> seen = const []}) =>
    P2pPeer(
      deviceAddress: '02:00:00:00:00:${id.substring(0, 2)}',
      deviceId: id,
      name: name,
      seen: {for (final s in seen) shortId(s)},
    );

const hostingAlone = P2pGroup(enabled: true, formed: true, isOwner: true);

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
    p.group(P2pGroup.unknown);
    async.flushMicrotasks();
    body(async, p, controller);
    controller.stop();
    async.flushMicrotasks();
  });
}

void tick(FakeAsync async) => async.elapse(WifiDirectController.tickInterval);

void main() {
  test('credentials come from the host ID and fit Wi-Fi Direct rules', () {
    final credentials = groupCredentials(a);
    expect(credentials.networkName, 'DIRECT-LU-aaaaaaaa');
    expect(credentials.passphrase, hasLength(24));
    expect(groupCredentials(a), credentials, reason: 'the same on every phone');
    expect(groupCredentials(b).passphrase, isNot(credentials.passphrase));
  });

  test('a phone without Wi-Fi Direct (or before Android 10) says so', () {
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
      tick(async);
      expect(c.current.phase, WifiDirectPhase.searching);
      p.group(const P2pGroup(enabled: false, formed: false));
      async.flushMicrotasks();
      expect(c.current.phase, WifiDirectPhase.wifiOff);
    }, platform: p);
  });

  test('phones seen are advertised', () {
    run(a, (async, p, ctl) {
      p.see(phone(c, 'Karim'));
      p.see(phone(b, 'Rahim'));
      tick(async);
      expect(p.advertised, ['bbbbbbbb', 'cccccccc']);
    });
  });

  test('the lowest hosts only once the other phone has seen it', () {
    run(a, (async, p, ctl) {
      // Rahim is seen, but hasn't seen this phone yet: nothing happens. (A
      // group made now couldn't be found by Rahim.)
      p.see(phone(b, 'Rahim'));
      async.elapse(const Duration(seconds: 15));
      expect(p.calls, isNot(contains('create')));
      expect(ctl.current.phase, WifiDirectPhase.searching);
      expect(ctl.current.nearby, 1);

      p.see(phone(b, 'Rahim', seen: [a]));
      tick(async);
      expect(p.created, groupCredentials(a));
      expect(ctl.current.phase, WifiDirectPhase.connecting);

      p.group(hostingAlone);
      async.flushMicrotasks();
      expect(ctl.current.phase, WifiDirectPhase.hosting);
    });
  });

  test('a higher ID joins the lowest mutual phone by its credentials', () {
    run(c, (async, p, ctl) {
      p
        ..see(phone(b, 'Rahim', seen: [c]))
        ..see(phone(a, 'Karim', seen: [c]));
      tick(async);
      expect(p.joined, groupCredentials(a));
      expect(ctl.current.phase, WifiDirectPhase.connecting);
      expect(ctl.current.hostName, 'Karim');

      p.group(const P2pGroup(enabled: true, formed: true));
      async.flushMicrotasks();
      expect(ctl.current.phase, WifiDirectPhase.joined);
      expect(ctl.current.hostName, 'Karim');
    });
  });

  test('a lower phone that has not seen us yet is not joined', () {
    run(b, (async, p, ctl) {
      p.see(phone(a, 'Karim'));
      async.elapse(const Duration(seconds: 15));
      expect(p.calls.where((x) => x.startsWith('join')), isEmpty);
      expect(p.calls, isNot(contains('create')));
    });
  });

  test('a join that never forms is tried again', () {
    run(c, (async, p, ctl) {
      p.see(phone(a, 'Karim', seen: [c]));
      tick(async);
      expect(p.calls.where((x) => x.startsWith('join')), hasLength(1));
      p.see(phone(a, 'Karim', seen: [c]));
      async.elapse(const Duration(seconds: 25));
      expect(p.calls.where((x) => x.startsWith('join')), hasLength(2));
    });
  });

  test('a refused create goes back to searching', () {
    final p = FakeWifiDirect()..refuseWith = 'busy';
    run(a, (async, p, c) {
      p.see(phone(b, 'Rahim', seen: [a]));
      tick(async);
      expect(p.calls, contains('create'));
      expect(c.current.phase, WifiDirectPhase.searching);
    }, platform: p);
  });

  test('a host nobody joined gives way to a lower mutual phone', () {
    run(b, (async, p, c) {
      p
        ..group(hostingAlone)
        ..see(phone(a, 'Karim', seen: [b]));
      tick(async);
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
        ..see(phone(a, 'Karim', seen: [b]));
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

  test('phones not heard from for 2 minutes are forgotten', () {
    run(c, (async, p, ctl) {
      p.see(phone(b, 'Rahim'));
      async.flushMicrotasks();
      expect(ctl.current.nearby, 1);
      async.elapse(const Duration(minutes: 3));
      expect(ctl.current.nearby, 0);
    });
  });

  test('a new name is advertised', () {
    run(a, (async, p, c) {
      c.nameChanged();
      async.flushMicrotasks();
      expect(p.starts, hasLength(2));
    });
  });
}
