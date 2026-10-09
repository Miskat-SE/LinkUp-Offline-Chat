import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/discovery/datagram_transport.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/utils/relative_time.dart';
import 'package:resqmesh/features/discovery/domain/display_names.dart';

LanInterface iface(String ip, int prefix) => LanInterface(
  name: 'wlan0',
  address: ip,
  prefixLength: prefix,
  kind: LanInterfaceKind.wifi,
);

void main() {
  group('LanInterface', () {
    test('computes broadcast and subnet', () {
      expect(iface('192.168.0.105', 24).broadcast, '192.168.0.255');
      expect(iface('192.168.0.105', 24).subnet, '192.168.0.0/24');
      expect(iface('10.12.34.56', 16).broadcast, '10.12.255.255');
      expect(iface('172.20.10.3', 28).broadcast, '172.20.10.15');
      expect(iface('172.20.10.3', 28).subnet, '172.20.10.0/28');
    });
  });

  group('NetworkSnapshot', () {
    test(
      'a LAN exists with Wi-Fi or an own hotspot, never needing internet',
      () {
        expect(NetworkSnapshot.none.hasLan, isFalse);
        final hotspot = NetworkSnapshot(
          wifiConnected: false,
          boundToWifi: false,
          interfaces: [
            const LanInterface(
              name: 'ap0',
              address: '192.168.43.1',
              prefixLength: 24,
              kind: LanInterfaceKind.hotspot,
            ),
          ],
        );
        expect(hotspot.hasLan, isTrue);
        expect(hotspot.isHotspotHost, isTrue);
      },
    );

    test('broadcasts to each subnet and the limited address, once each', () {
      final snapshot = NetworkSnapshot(
        wifiConnected: true,
        boundToWifi: true,
        interfaces: [iface('192.168.0.5', 24), iface('192.168.0.5', 24)],
      );
      expect(snapshot.broadcastTargets, ['192.168.0.255', '255.255.255.255']);
    });
  });

  test('real UDP sockets exchange datagrams on loopback', () async {
    final a = await bindUdp(0) as UdpDatagramTransport;
    final b = await bindUdp(0) as UdpDatagramTransport;
    addTearDown(() async {
      await a.close();
      await b.close();
    });
    final received = b.incoming.first.timeout(const Duration(seconds: 5));
    a.send(Uint8List.fromList(utf8.encode('RQM1 hello')), '127.0.0.1', b.port);
    final datagram = await received;
    expect(utf8.decode(datagram.data), 'RQM1 hello');
    expect(datagram.address, '127.0.0.1');
    expect(datagram.port, a.port);
  });

  group('display names', () {
    test('add a short ID only where names clash', () {
      final labels = displayNames([
        (deviceId: 'aaaa1111-0000-4000-8000-000000000001', name: 'Yusuf'),
        (deviceId: 'bbbb2222-0000-4000-8000-000000000002', name: 'yusuf'),
        (deviceId: 'cccc3333-0000-4000-8000-000000000003', name: 'Rahim'),
      ]);
      expect(labels.values, ['Yusuf · aaaa', 'yusuf · bbbb', 'Rahim']);
    });

    test('mark a peer that uses this device’s name', () {
      final labels = displayNames([
        (deviceId: 'bbbb2222-0000-4000-8000-000000000002', name: 'Yusuf'),
      ], selfName: 'yusuf');
      expect(labels.values.single, 'Yusuf · bbbb');
    });
  });

  test('relative time', () {
    final now = DateTime(2026, 10, 8, 12);
    expect(
      relativeTime(now.subtract(const Duration(seconds: 30)), now),
      'just now',
    );
    expect(
      relativeTime(now.subtract(const Duration(minutes: 5)), now),
      '5 min ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(hours: 3)), now),
      '3 h ago',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 1)), now),
      'yesterday',
    );
    expect(
      relativeTime(now.subtract(const Duration(days: 4)), now),
      '4 days ago',
    );
  });
}
