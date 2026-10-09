import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/discovery/service_discovery.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/network/protocol/datagram.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

import '../../../support/fake_network_monitor.dart';
import '../../../support/memory_datagram_network.dart';

const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';
const idC = 'cccccccc-0000-4000-8000-000000000003';

/// One phone in a test LAN.
final class Phone {
  Phone(
    this.lan, {
    required this.id,
    required this.ip,
    String? name,
    DateTime? claimedAt,
    bool announce = true,
    bool blocked = false,
    ServiceDiscovery? nsd,
  }) : monitor = FakeNetworkMonitor.onWifi(ip) {
    engine = DiscoveryEngine(
      network: monitor,
      bindUdp: lan.binderFor(ip, blocked: blocked),
      logger: AppLogger(),
      serviceDiscovery: nsd,
      random: Random(1),
      self: SelfInfo(
        deviceId: id,
        name: name,
        nameClaimedAt: name == null ? null : claimedAt ?? DateTime.utc(2026),
        announce: announce,
        appVersion: '1.0.0+3',
      ),
    );
  }

  final MemoryDatagramNetwork lan;
  final String id;
  final String ip;
  final FakeNetworkMonitor monitor;
  late final DiscoveryEngine engine;

  DiscoverySnapshot get now => engine.current;

  Peer? peer(String id) {
    for (final p in now.peers) {
      if (p.deviceId == id) return p;
    }
    return null;
  }
}

void main() {
  late MemoryDatagramNetwork lan;

  setUp(() => lan = MemoryDatagramNetwork());

  void startAll(FakeAsync async, List<Phone> phones) {
    for (final phone in phones) {
      unawaited(phone.engine.start());
    }
    async.flushMicrotasks();
  }

  test('two phones find each other within a second', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));

      expect(a.peer(idB)?.name, 'Rahim');
      expect(a.peer(idB)?.address, '192.168.0.11');
      expect(a.peer(idB)?.online, isTrue);
      expect(b.peer(idA)?.name, 'Yusuf');
      expect(a.now.state, LanState.connected);
      expect(a.now.onlineCount, 1);
      expect(a.monitor.multicastLockHeld, isTrue);
    });
  });

  test('a phone that disappears goes offline after 20 s', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));

      lan.unreachable.add(b.ip); // walked away, no GOODBYE
      async.elapse(const Duration(seconds: 15));
      expect(a.peer(idB)?.online, isTrue, reason: 'not yet 20 s');

      async.elapse(const Duration(seconds: 10));
      expect(a.peer(idB)?.online, isFalse);
      expect(a.now.state, LanState.searching);
    });
  });

  test('GOODBYE marks a phone offline at once', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));

      unawaited(b.engine.stop());
      async.flushMicrotasks();
      expect(a.peer(idB)?.online, isFalse);
    });
  });

  test('a phone that comes back is online again', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));
      lan.unreachable.add(b.ip);
      async.elapse(const Duration(seconds: 30));
      expect(a.peer(idB)?.online, isFalse);

      lan.unreachable.remove(b.ip);
      async.elapse(const Duration(seconds: 7));
      expect(a.peer(idB)?.online, isTrue);
    });
  });

  test('a broken UDP socket is opened again and discovery recovers', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));
      expect(a.peer(idB)?.online, isTrue);

      // Android cut Yusuf's network for a moment (app in the background).
      lan.breakSocket(a.ip);
      async.elapse(const Duration(seconds: 1));
      expect(a.now.stats.recentErrors.last, contains('UDP receive failed'));

      // Reopened after 2 s; Rahim answers the fresh DISCOVERY at once.
      async.elapse(const Duration(seconds: 2));
      expect(a.peer(idB)?.online, isTrue);
      final seenBefore = a.peer(idB)!.lastSeen;
      async.elapse(const Duration(seconds: 30));
      expect(a.peer(idB)?.online, isTrue, reason: 'still hearing Rahim');
      expect(a.peer(idB)!.lastSeen.isAfter(seenBefore), isTrue);
    });
  });

  test('answers to one address are limited (no amplification)', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      startAll(async, [a]);
      async.elapse(const Duration(seconds: 1));
      // A listener at the spoofed victim's address counts what it gets.
      var answers = 0;
      unawaited(
        lan
            .binderFor('192.168.0.66')(28760)
            .then(
              (victim) => victim.incoming.listen((d) {
                final decoded = DatagramCodec.decode(d.data);
                if (decoded case Decoded(packet: DiscoveryResponsePacket())) {
                  answers++;
                }
              }),
            ),
      );
      async.flushMicrotasks();
      final ask = DatagramCodec.encode(
        DiscoveryPacket(PacketHeader.create(senderId: idC, senderName: '')),
      );
      for (var i = 0; i < 100; i++) {
        lan.inject(ask, fromIp: '192.168.0.66', toPort: 28760);
      }
      async.elapse(const Duration(seconds: 2));
      expect(answers, 10);
      // A new window allows more.
      async.elapse(const Duration(seconds: 10));
      lan.inject(ask, fromIp: '192.168.0.66', toPort: 28760);
      async.elapse(const Duration(seconds: 1));
      expect(answers, 11);
    });
  });

  test('duplicate announcements keep a single peer entry', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      // Every HELLO goes to two broadcast addresses, every 5 s.
      async.elapse(const Duration(minutes: 1));
      expect(a.now.peers, hasLength(1));
      expect(a.now.stats.received['HELLO'], greaterThan(10));
    });
  });

  test('an IP change is picked up from the next announcement', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));

      // B gets a new address: the old endpoint goes quiet, a new one binds.
      lan.unreachable.add('192.168.0.11');
      final moved = Phone(lan, id: idB, ip: '192.168.0.42', name: 'Rahim');
      startAll(async, [moved]);
      async.elapse(const Duration(seconds: 1));

      expect(a.peer(idB)?.address, '192.168.0.42');
      expect(a.now.peers, hasLength(1));
    });
  });

  test('losing the local network marks everyone offline', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 1));

      a.monitor.set(NetworkSnapshot.none);
      async.flushMicrotasks();
      expect(a.now.state, LanState.noNetwork);
      expect(a.peer(idB)?.online, isFalse);
      expect(a.now.udpPort, isNull);
      expect(a.monitor.multicastLockHeld, isFalse);

      a.monitor.set(FakeNetworkMonitor.wifiSnapshot('192.168.0.10'));
      async.elapse(const Duration(seconds: 1));
      expect(a.peer(idB)?.online, isTrue, reason: 'rediscovered after Wi-Fi');
    });
  });

  test('a phone without a connection method listens but does not announce', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10');
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 12));

      expect(a.peer(idB), isNotNull, reason: 'onboarding phone sees others');
      expect(b.now.peers, isEmpty, reason: 'nobody sees it yet');
    });
  });

  group('name check', () {
    test('a name used by an online phone is taken, ignoring case', () {
      fakeAsync((async) {
        final a = Phone(lan, id: idA, ip: '192.168.0.10');
        final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Yusuf');
        startAll(async, [a, b]);
        async.elapse(const Duration(seconds: 1));

        NameCheckResult? result;
        unawaited(a.engine.checkName('yusuf').then((r) => result = r));
        async.flushMicrotasks();
        expect(result?.outcome, NameCheckOutcome.taken);
      });
    });

    test('NAME_CHECK finds a holder that has not been seen yet', () {
      fakeAsync((async) {
        final a = Phone(lan, id: idA, ip: '192.168.0.10');
        startAll(async, [a]);
        // B is on the network, but A has not heard from it yet.
        final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Yusuf');
        lan.unreachable.add(b.ip);
        startAll(async, [b]);
        lan.unreachable.remove(b.ip);

        NameCheckResult? result;
        unawaited(a.engine.checkName('Yusuf').then((r) => result = r));
        async.elapse(const Duration(milliseconds: 100));
        expect(result?.outcome, NameCheckOutcome.taken);
      });
    });

    test('a free name is available after waiting 3 s', () {
      fakeAsync((async) {
        final a = Phone(lan, id: idA, ip: '192.168.0.10');
        final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
        startAll(async, [a, b]);
        async.elapse(const Duration(seconds: 1));

        NameCheckResult? result;
        unawaited(a.engine.checkName('Yusuf').then((r) => result = r));
        async.elapse(const Duration(seconds: 2));
        expect(result, isNull, reason: 'still waiting for answers');
        async.elapse(const Duration(seconds: 2));
        expect(result?.outcome, NameCheckOutcome.available);
      });
    });

    test('without a local network the name is unverified', () {
      fakeAsync((async) {
        final a = Phone(lan, id: idA, ip: '192.168.0.10');
        a.monitor.set(NetworkSnapshot.none);
        startAll(async, [a]);

        NameCheckResult? result;
        unawaited(a.engine.checkName('Yusuf').then((r) => result = r));
        async.flushMicrotasks();
        expect(result?.outcome, NameCheckOutcome.unverified);
      });
    });
  });

  group('name clash', () {
    test('the later claim loses and is told to rename', () {
      fakeAsync((async) {
        final a = Phone(
          lan,
          id: idA,
          ip: '192.168.0.10',
          name: 'Yusuf',
          claimedAt: DateTime.utc(2026, 10),
        );
        final b = Phone(
          lan,
          id: idB,
          ip: '192.168.0.11',
          name: 'yusuf',
          claimedAt: DateTime.utc(2026, 10, 2),
        );
        startAll(async, [a, b]);
        async.elapse(const Duration(seconds: 1));

        expect(a.now.clash, isNull);
        expect(b.now.clash?.holderId, idA);
      });
    });

    test('equal claim times go to the lower device ID', () {
      fakeAsync((async) {
        final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Yusuf');
        final c = Phone(lan, id: idC, ip: '192.168.0.12', name: 'Yusuf');
        startAll(async, [b, c]);
        async.elapse(const Duration(seconds: 1));

        expect(b.now.clash, isNull);
        expect(c.now.clash?.holderId, idB);
      });
    });

    test('renaming clears the clash', () {
      fakeAsync((async) {
        final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
        final b = Phone(
          lan,
          id: idB,
          ip: '192.168.0.11',
          name: 'Yusuf',
          claimedAt: DateTime.utc(2026, 5),
        );
        startAll(async, [a, b]);
        async.elapse(const Duration(seconds: 1));
        expect(b.now.clash, isNotNull);

        b.engine.updateSelf(
          SelfInfo(
            deviceId: idB,
            name: 'Rahim',
            nameClaimedAt: DateTime.utc(2026, 6),
            announce: true,
          ),
        );
        async.elapse(const Duration(seconds: 1));
        expect(b.now.clash, isNull);
        expect(a.peer(idB)?.name, 'Rahim', reason: 'new name announced');
      });
    });
  });

  test('blocked local network access shows as blocked', () {
    fakeAsync((async) {
      final a = Phone(
        lan,
        id: idA,
        ip: '192.168.0.10',
        name: 'Yusuf',
        blocked: true,
      );
      startAll(async, [a]);
      expect(a.now.state, LanState.blocked);
    });
  });

  test('isolation is suspected after 30 s alone on a network', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      startAll(async, [a]);
      async.elapse(const Duration(seconds: 20));
      expect(a.now.isolationSuspected, isFalse);
      async.elapse(const Duration(seconds: 12));
      expect(a.now.state, LanState.searching);
      expect(a.now.isolationSuspected, isTrue);
    });
  });

  test('garbage and other apps on the port are counted, not fatal', () {
    fakeAsync((async) {
      final a = Phone(lan, id: idA, ip: '192.168.0.10', name: 'Yusuf');
      startAll(async, [a]);

      lan
        ..inject(
          Uint8List.fromList([1, 2, 3, 4, 5]),
          fromIp: '1.2.3.4',
          toPort: 28760,
        )
        ..inject(
          Uint8List.fromList([...'RQM1'.codeUnits, ...'{not json'.codeUnits]),
          fromIp: '1.2.3.4',
          toPort: 28760,
        );
      async.flushMicrotasks();

      expect(a.now.stats.foreign, 1);
      expect(a.now.stats.malformed, 1);
      expect(a.now.peers, isEmpty);
    });
  });

  test('NSD finds a phone even when the router drops broadcasts', () {
    fakeAsync((async) {
      lan.dropBroadcasts = true;
      final nsd = _FakeServiceDiscovery();
      final a = Phone(
        lan,
        id: idA,
        ip: '192.168.0.10',
        name: 'Yusuf',
        nsd: nsd,
      );
      final b = Phone(lan, id: idB, ip: '192.168.0.11', name: 'Rahim');
      startAll(async, [a, b]);
      async.elapse(const Duration(seconds: 10));
      expect(a.peer(idB), isNull, reason: 'broadcasts are dropped');

      nsd.found(idB, '192.168.0.11');
      async.elapse(const Duration(seconds: 1));
      expect(a.peer(idB)?.online, isTrue);
      expect(a.peer(idB)?.sources, contains(DiscoverySource.nsd));
      expect(nsd.advertisedId, idA);
    });
  });
}

final class _FakeServiceDiscovery implements ServiceDiscovery {
  final StreamController<ServiceCandidate> _candidates =
      StreamController<ServiceCandidate>.broadcast();
  String? advertisedId;

  void found(String deviceId, String address) =>
      _candidates.add(ServiceCandidate(deviceId: deviceId, address: address));

  @override
  Stream<ServiceCandidate> get candidates => _candidates.stream;

  @override
  Future<void> startBrowsing() async {}

  @override
  Future<void> advertise({required String deviceId, required int port}) async {
    advertisedId = deviceId;
  }

  @override
  Future<void> stopAdvertising() async => advertisedId = null;

  @override
  Future<void> stop() async {}
}
