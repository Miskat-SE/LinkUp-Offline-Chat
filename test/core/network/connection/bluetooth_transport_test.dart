import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/bluetooth_transport.dart';
import 'package:resqmesh/core/network/connection/connection_manager.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

import '../../../support/fake_bluetooth.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';

/// A phone whose connections run over (fake) Bluetooth.
final class BtPhone {
  BtPhone(this.id, this.name, FakeAir air, String address)
    : bluetooth = FakeBluetooth(address: address, air: air) {
    transport = BluetoothTransport(bluetooth);
    links = ConnectionManager(
      self: () => SelfInfo(
        deviceId: id,
        name: name,
        nameClaimedAt: DateTime.utc(2026),
        announce: true,
        appVersion: 'test',
      ),
      logger: AppLogger(),
      transport: transport,
      timing: const ConnectionTiming(dialGrace: Duration(milliseconds: 50)),
    );
  }

  final String id;
  final String name;
  final FakeBluetooth bluetooth;
  late final BluetoothTransport transport;
  late final ConnectionManager links;
  late int channel;

  Future<void> start() async => channel = (await links.start())!;

  Future<void> stop() async {
    await links.stop();
    await transport.dispose();
  }
}

Future<void> eventually(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('two phones connect over Bluetooth and exchange packets', () async {
    final air = FakeAir();
    final yusuf = BtPhone(idA, 'Yusuf', air, 'AA:00:00:00:00:01');
    final rahim = BtPhone(idB, 'Rahim', air, 'BB:00:00:00:00:02');
    addTearDown(yusuf.stop);
    addTearDown(rahim.stop);
    await yusuf.start();
    await rahim.start();
    expect(yusuf.channel, isPositive);

    // Each found the other by Bluetooth LE; the lower ID (Yusuf) dials.
    yusuf.links.updateEndpoints([
      PeerEndpoint(
        deviceId: idB,
        address: 'BB:00:00:00:00:02',
        port: rahim.channel,
      ),
    ]);
    rahim.links.updateEndpoints([
      PeerEndpoint(
        deviceId: idA,
        address: 'AA:00:00:00:00:01',
        port: yusuf.channel,
      ),
    ]);
    await eventually(
      () =>
          yusuf.links.current.links.containsKey(idB) &&
          rahim.links.current.links.containsKey(idA),
    );
    expect(yusuf.links.current.links[idB]!.peerName, 'Rahim');
    expect(rahim.links.current.links[idA]!.peerName, 'Yusuf');

    final got = rahim.links.packets.first;
    yusuf.links.send(
      idB,
      MessagePacket(
        PacketHeader.create(
          senderId: idA,
          senderName: 'Yusuf',
          receiverId: idB,
        ),
        kind: MessageKind.text,
        audience: MessageAudience.direct,
        text: 'Over Bluetooth',
      ),
    );
    final packet = await got.timeout(const Duration(seconds: 2));
    expect(packet.from, idA);
    expect((packet.packet as MessagePacket).text, 'Over Bluetooth');

    // Rahim's app stops: Yusuf sees the link close.
    await rahim.stop();
    await eventually(() => !yusuf.links.current.links.containsKey(idB));
    expect(yusuf.links.current.links, isEmpty);
  });

  test('an unreachable phone is a failed dial, retried later', () async {
    final air = FakeAir();
    final yusuf = BtPhone(idA, 'Yusuf', air, 'AA:00:00:00:00:01');
    addTearDown(yusuf.stop);
    await yusuf.start();
    yusuf.links.updateEndpoints([
      const PeerEndpoint(deviceId: idB, address: 'BB:00:00:00:00:02', port: 9),
    ]);
    await eventually(() => yusuf.links.current.stats.dialFailures > 0);
    expect(yusuf.links.current.stats.dialFailures, greaterThan(0));
    expect(yusuf.links.current.links, isEmpty);
  });
}
