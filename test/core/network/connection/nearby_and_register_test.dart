import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/connection/register_handler.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

import '../../../support/fake_network_monitor.dart';
import '../../../support/fake_peer_links.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';
const idC = 'cccccccc-0000-4000-8000-000000000003';
const idD = 'dddddddd-0000-4000-8000-000000000004';

Peer peer(String id, String name, {bool online = true}) => Peer(
  deviceId: id,
  name: name,
  nameClaimedAt: DateTime.utc(2026),
  address: '192.168.0.${id.codeUnitAt(0)}',
  tcpPort: 28761,
  appVersion: '1',
  firstSeen: DateTime.utc(2026),
  lastSeen: DateTime.utc(2026),
  online: online,
  sources: const {DiscoverySource.udp},
);

DiscoverySnapshot discovery(List<Peer> peers, {LanState? state}) =>
    DiscoverySnapshot(
      state:
          state ??
          (peers.any((p) => p.online)
              ? LanState.connected
              : LanState.searching),
      network: FakeNetworkMonitor.wifiSnapshot('192.168.0.10'),
      peers: peers,
      isolationSuspected: false,
      clash: null,
      stats: const DiscoveryStats(),
      udpPort: 28760,
      nsdEnabled: false,
    );

LinkInfo link(String id, String name) => LinkInfo(
  peerId: id,
  peerName: name,
  address: '192.168.0.99',
  direction: ConnectionDirection.inbound,
  connectedAt: DateTime.utc(2026),
  rttMs: 5,
);

LinksSnapshot links(
  Map<String, LinkInfo> links, {
  Set<String> unreachable = const {},
}) => LinksSnapshot(
  listeningPort: 28761,
  links: links,
  unreachable: unreachable,
  stats: const LinkStats(),
);

void main() {
  group('NearbySnapshot', () {
    test('only connected devices count as online', () {
      final nearby = NearbySnapshot.combine(
        discovery([
          peer(idB, 'Rahim'),
          peer(idC, 'Karim'),
          peer(idD, 'Zara', online: false),
        ]),
        links({idB: link(idB, 'Rahim')}),
      );
      expect(nearby.status, NearbyStatus.connected);
      expect(nearby.connectedCount, 1);
      expect(
        {for (final p in nearby.peers) p.peer.name: p.link},
        {
          'Rahim': LinkState.connected,
          'Karim': LinkState.connecting,
          'Zara': LinkState.offline,
        },
      );
    });

    test('found but never reachable shows why', () {
      final nearby = NearbySnapshot.combine(
        discovery([peer(idB, 'Rahim')]),
        links({}, unreachable: {idB}),
      );
      expect(nearby.status, NearbyStatus.unreachable);
      expect(nearby.firstUnreachable?.peer.name, 'Rahim');
    });

    test('a device that connected before discovery saw it still appears', () {
      final nearby = NearbySnapshot.combine(
        discovery([]),
        links({idC: link(idC, 'Karim')}),
      );
      expect(nearby.peers.single.peer.name, 'Karim');
      expect(nearby.peers.single.peer.sources, {DiscoverySource.tcp});
      expect(nearby.status, NearbyStatus.connected);
    });

    test('no network wins over stale connections', () {
      final nearby = NearbySnapshot.combine(
        DiscoverySnapshot.initial,
        links({idB: link(idB, 'Rahim')}),
      );
      expect(nearby.status, NearbyStatus.noNetwork);
      expect(NetworkSnapshot.none.hasLan, isFalse);
    });
  });

  group('RegisterHandler', () {
    late FakePeerLinks fake;
    late List<(String, String)> renames;
    late SelfInfo self;
    late RegisterHandler handler;

    setUp(() {
      fake = FakePeerLinks()
        ..updateEndpoints([
          const PeerEndpoint(deviceId: idB, address: '192.168.0.11', port: 1),
        ]);
      renames = [];
      self = SelfInfo(
        deviceId: idA,
        name: 'Yusuf',
        nameClaimedAt: DateTime.utc(2026),
        announce: true,
      );
      handler = RegisterHandler(
        links: fake,
        self: () => self,
        onRename: (id, name, _) => renames.add((id, name)),
        logger: AppLogger(),
      )..start();
      addTearDown(handler.stop);
    });

    RegisterPacket registerFrom(String id, String name, DateTime claimedAt) =>
        RegisterPacket(
          PacketHeader.create(senderId: id, senderName: name),
          name: name,
          nameClaimedAt: claimedAt,
        );

    test('a rename is applied and answered with ok', () async {
      fake.receive(idB, registerFrom(idB, 'Rahim', DateTime.utc(2026, 5)));
      await pumpEventQueue();

      expect(renames, [(idB, 'Rahim')]);
      final (to, answer) = fake.sent.single;
      expect(to, idB);
      expect((answer as RegisterResponsePacket).result, RegisterResult.ok);
    });

    test(
      'taking a name this device claimed earlier is answered nameTaken',
      () async {
        fake.receive(idB, registerFrom(idB, 'yusuf', DateTime.utc(2026, 5)));
        await pumpEventQueue();

        final answer = fake.sent.single.$2 as RegisterResponsePacket;
        expect(answer.result, RegisterResult.nameTaken);
        expect(answer.holderId, idA);
      },
    );

    test('announce sends REGISTER to every connection', () {
      handler.announce();
      final (to, packet) = fake.sent.single;
      expect(to, idB);
      expect((packet as RegisterPacket).name, 'Yusuf');
    });
  });
}
