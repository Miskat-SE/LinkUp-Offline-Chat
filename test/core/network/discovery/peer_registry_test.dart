import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/discovery/peer_registry.dart';

const _a = 'aaaaaaaa-0000-4000-8000-000000000001';
const _b = 'bbbbbbbb-0000-4000-8000-000000000002';
final _t0 = DateTime.utc(2026, 10, 8, 12);

PeerUpdate see(
  PeerRegistry registry,
  String id, {
  String name = 'Yusuf',
  String address = '192.168.0.10',
  DiscoverySource source = DiscoverySource.udp,
  Duration at = Duration.zero,
}) => registry.observe(
  deviceId: id,
  name: name,
  nameClaimedAt: DateTime.utc(2026),
  address: address,
  tcpPort: 28761,
  appVersion: '1.0.0+3',
  source: source,
  now: _t0.add(at),
);

void main() {
  late PeerRegistry registry;

  setUp(
    () => registry = PeerRegistry(offlineAfter: const Duration(seconds: 20)),
  );

  test('reports added, refreshed, changed and back online', () {
    expect(see(registry, _a), PeerUpdate.added);
    expect(see(registry, _a), PeerUpdate.refreshed);
    expect(see(registry, _a, address: '192.168.0.99'), PeerUpdate.changed);
    registry.expire(_t0.add(const Duration(minutes: 1)));
    expect(
      see(registry, _a, at: const Duration(minutes: 2)),
      PeerUpdate.cameOnline,
    );
  });

  test('merges sources by device ID', () {
    see(registry, _a);
    see(registry, _a, source: DiscoverySource.nsd);
    expect(registry.all, hasLength(1));
    expect(registry[_a]!.sources, {DiscoverySource.udp, DiscoverySource.nsd});
  });

  test('expires peers after the offline timeout only', () {
    see(registry, _a);
    expect(registry.expire(_t0.add(const Duration(seconds: 19))), isEmpty);
    final gone = registry.expire(_t0.add(const Duration(seconds: 20)));
    expect(gone.single.deviceId, _a);
    expect(registry[_a]!.online, isFalse);
    expect(registry.expire(_t0.add(const Duration(minutes: 5))), isEmpty);
  });

  test('GOODBYE takes a peer offline once', () {
    see(registry, _a);
    expect(registry.goodbye(_a, _t0), isTrue);
    expect(registry.goodbye(_a, _t0), isFalse);
    expect(registry.goodbye(_b, _t0), isFalse);
  });

  test('lists online peers first, then by name', () {
    see(registry, _a, name: 'Zara');
    see(registry, _b, name: 'amir', at: const Duration(seconds: 30));
    registry.expire(_t0.add(const Duration(seconds: 25)));
    expect(registry.all.map((p) => p.name), ['amir', 'Zara']);
  });

  test('finds who holds a name, ignoring case and itself', () {
    see(registry, _a);
    expect(registry.onlineHolderOf('yusuf', exceptId: _b)?.deviceId, _a);
    expect(registry.onlineHolderOf('yusuf', exceptId: _a), isNull);
    registry.markAllOffline();
    expect(registry.onlineHolderOf('Yusuf', exceptId: _b), isNull);
  });

  test('earlier claims win name clashes, ties go to the lower ID', () {
    final early = DateTime.utc(2026);
    final late = DateTime.utc(2026, 2);
    expect(
      Peer.winsNameClash(
        claimedAt: early,
        deviceId: _b,
        otherClaimedAt: late,
        otherId: _a,
      ),
      isTrue,
    );
    expect(
      Peer.winsNameClash(
        claimedAt: late,
        deviceId: _a,
        otherClaimedAt: early,
        otherId: _b,
      ),
      isFalse,
    );
    expect(
      Peer.winsNameClash(
        claimedAt: early,
        deviceId: _a,
        otherClaimedAt: early,
        otherId: _b,
      ),
      isTrue,
    );
    expect(
      Peer.winsNameClash(
        claimedAt: early,
        deviceId: _b,
        otherClaimedAt: early,
        otherId: _a,
      ),
      isFalse,
    );
  });
}
