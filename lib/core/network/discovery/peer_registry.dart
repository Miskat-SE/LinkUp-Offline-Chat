import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';

/// What [PeerRegistry.observe] changed.
enum PeerUpdate {
  /// First time this device was seen.
  added,

  /// Seen before, offline until now.
  cameOnline,

  /// Already online; its name, address or port changed.
  changed,

  /// Already online; nothing new except the time it was last seen.
  refreshed,
}

/// Every device heard from, merged by device ID however it was found
/// (PROJECT_PLAN.md §6.2–6.3). Pure Dart; time is passed in.
final class PeerRegistry {
  PeerRegistry({required this.offlineAfter});

  /// A peer with no announcement for this long goes offline.
  final Duration offlineAfter;

  final Map<String, Peer> _peers = {};

  Peer? operator [](String deviceId) => _peers[deviceId];

  /// Online first, then by name.
  List<Peer> get all {
    final list = _peers.values.toList()
      ..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return Username.key(a.name).compareTo(Username.key(b.name));
      });
    return list;
  }

  Iterable<Peer> get online => _peers.values.where((p) => p.online);

  PeerUpdate observe({
    required String deviceId,
    required String name,
    required DateTime nameClaimedAt,
    required String address,
    required int tcpPort,
    required String appVersion,
    required DiscoverySource source,
    required DateTime now,
  }) {
    final existing = _peers[deviceId];
    if (existing == null) {
      _peers[deviceId] = Peer(
        deviceId: deviceId,
        name: name,
        nameClaimedAt: nameClaimedAt,
        address: address,
        tcpPort: tcpPort,
        appVersion: appVersion,
        firstSeen: now,
        lastSeen: now,
        online: true,
        sources: {source},
      );
      return PeerUpdate.added;
    }
    final changed =
        existing.name != name ||
        existing.address != address ||
        existing.tcpPort != tcpPort ||
        existing.nameClaimedAt != nameClaimedAt;
    _peers[deviceId] = existing.copyWith(
      name: name,
      nameClaimedAt: nameClaimedAt,
      address: address,
      tcpPort: tcpPort,
      appVersion: appVersion,
      lastSeen: now,
      online: true,
      sources: {...existing.sources, source},
    );
    if (!existing.online) return PeerUpdate.cameOnline;
    return changed ? PeerUpdate.changed : PeerUpdate.refreshed;
  }

  /// Updates a known peer's name. Returns false for unknown devices.
  bool rename(String deviceId, String name, DateTime nameClaimedAt) {
    final peer = _peers[deviceId];
    if (peer == null) return false;
    _peers[deviceId] = peer.copyWith(name: name, nameClaimedAt: nameClaimedAt);
    return true;
  }

  /// The peer said GOODBYE. Returns whether it was online.
  bool goodbye(String deviceId, DateTime now) {
    final peer = _peers[deviceId];
    if (peer == null || !peer.online) return false;
    _peers[deviceId] = peer.copyWith(online: false);
    return true;
  }

  /// Marks peers not heard from within [offlineAfter] as offline and
  /// returns them.
  List<Peer> expire(DateTime now) {
    final gone = <Peer>[];
    for (final peer in _peers.values.toList()) {
      if (peer.online && now.difference(peer.lastSeen) >= offlineAfter) {
        final offline = peer.copyWith(online: false);
        _peers[peer.deviceId] = offline;
        gone.add(offline);
      }
    }
    return gone;
  }

  /// The local network went away: nobody is reachable.
  void markAllOffline() {
    for (final peer in _peers.values.toList()) {
      if (peer.online) _peers[peer.deviceId] = peer.copyWith(online: false);
    }
  }

  /// An online device, other than [exceptId], currently using [name].
  Peer? onlineHolderOf(String name, {required String exceptId}) {
    for (final peer in online) {
      if (peer.deviceId != exceptId && Username.same(peer.name, name)) {
        return peer;
      }
    }
    return null;
  }
}
