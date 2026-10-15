import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/connection/bluetooth_controller.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';

import '../../support/fake_bluetooth.dart';

const me = 'aaaaaaaa-0000-4000-8000-000000000001';
const rahim = 'bbbbbbbb-0000-4000-8000-000000000002';

void run(
  void Function(
    FakeAsync async,
    FakeBluetooth bt,
    BluetoothController c,
    List<List<PeerEndpoint>> endpoints,
  )
  body, {
  FakeBluetooth? bluetooth,
}) {
  fakeAsync((async) {
    final bt = bluetooth ?? FakeBluetooth();
    final controller = BluetoothController(
      platform: bt,
      deviceId: () => me,
      logger: AppLogger(),
    );
    final endpoints = <List<PeerEndpoint>>[];
    controller.endpoints.listen(endpoints.add);
    controller.start();
    async.flushMicrotasks();
    body(async, bt, controller, endpoints);
    controller.stop();
    async.flushMicrotasks();
  });
}

void main() {
  test('no Bluetooth LE (or before Android 10) is reported', () {
    run((async, bt, c, _) {
      expect(c.current.phase, BluetoothPhase.unsupported);
    }, bluetooth: FakeBluetooth()..supported = false);
  });

  test('discovery starts once the control channel is known', () {
    run((async, bt, c, _) {
      expect(c.current.phase, BluetoothPhase.searching);
      expect(bt.calls, isNot(contains('discover')));
      c.setChannel(0x81);
      async.flushMicrotasks();
      expect(bt.advertising, (deviceId: me, channel: 0x81));
    });
  });

  test('permission: asked, then discovery starts', () {
    final bt = FakeBluetooth()..permissionState = BtPermission.denied;
    run((async, bt, c, _) {
      c.setChannel(0x81);
      async.flushMicrotasks();
      expect(c.current.phase, BluetoothPhase.needsPermission);
      expect(bt.advertising, isNull);
      c.requestPermission();
      async.flushMicrotasks();
      expect(bt.advertising, isNotNull);
      expect(c.current.phase, BluetoothPhase.searching);
    }, bluetooth: bt);
  });

  test('Bluetooth off: reported; turning it on starts discovery', () {
    final bt = FakeBluetooth()..enabled = false;
    run((async, bt, c, _) {
      c.setChannel(0x81);
      async.flushMicrotasks();
      expect(c.current.phase, BluetoothPhase.off);
      c.requestEnable();
      async.flushMicrotasks();
      expect(bt.calls, contains('enable'));
      bt.setEnabled(true);
      async.flushMicrotasks();
      expect(c.current.phase, BluetoothPhase.searching);
      expect(bt.advertising, isNotNull);
    }, bluetooth: bt);
  });

  test('phones found become endpoints, and are forgotten when gone', () {
    run((async, bt, c, endpoints) {
      bt.see(const BtFound(address: 'BB:01', deviceId: rahim, channel: 0x85));
      async.flushMicrotasks();
      expect(endpoints.last.single.deviceId, rahim);
      expect(endpoints.last.single.address, 'BB:01');
      expect(endpoints.last.single.port, 0x85);
      expect(c.current.nearby, 1);

      // Seen again unchanged: no new list. A new address: a new list.
      bt.see(const BtFound(address: 'BB:01', deviceId: rahim, channel: 0x85));
      async.flushMicrotasks();
      expect(endpoints, hasLength(1));
      bt.see(const BtFound(address: 'BB:02', deviceId: rahim, channel: 0x85));
      async.flushMicrotasks();
      expect(endpoints.last.single.address, 'BB:02');

      async.elapse(const Duration(minutes: 1));
      expect(endpoints.last, isEmpty);
      expect(c.current.nearby, 0);
    });
  });

  test('this phone hearing itself is ignored', () {
    run((async, bt, c, endpoints) {
      bt.see(const BtFound(address: 'AA:01', deviceId: me, channel: 0x81));
      async.flushMicrotasks();
      expect(endpoints, isEmpty);
    });
  });
}
