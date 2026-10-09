import 'package:clock/clock.dart';
import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';

/// How well this device can reach a peer.
enum LinkState {
  /// A live control connection: the peer is online (PROJECT_PLAN.md D4).
  connected,

  /// Discovered; the connection is being set up.
  connecting,

  /// Discovered, but connecting keeps failing (router may block it).
  unreachable,

  /// Not heard from recently.
  offline,
}

/// The status line users see (spec §6, §31).
enum NearbyStatus { noNetwork, blocked, searching, connected, unreachable }

final class NearbyPeer {
  const NearbyPeer({required this.peer, required this.link, this.info});

  final Peer peer;
  final LinkState link;

  /// Connection details when connected.
  final LinkInfo? info;
}

/// What the UI shows about people nearby: discovery and TCP connections
/// combined.
final class NearbySnapshot {
  const NearbySnapshot({
    required this.status,
    required this.peers,
    required this.discovery,
    required this.links,
  });

  factory NearbySnapshot.combine(
    DiscoverySnapshot discovery,
    LinksSnapshot links,
  ) {
    final now = clock.now();
    final peers = <NearbyPeer>[
      for (final peer in discovery.peers)
        NearbyPeer(
          peer: peer,
          link: switch (peer) {
            _ when links.links.containsKey(peer.deviceId) =>
              LinkState.connected,
            Peer(online: false) => LinkState.offline,
            _ when links.unreachable.contains(peer.deviceId) =>
              LinkState.unreachable,
            _ => LinkState.connecting,
          },
          info: links.links[peer.deviceId],
        ),
      // Connected to us before discovery saw it (e.g. broadcasts blocked).
      for (final info in links.links.values)
        if (!discovery.peers.any((p) => p.deviceId == info.peerId))
          NearbyPeer(
            peer: Peer(
              deviceId: info.peerId,
              name: info.peerName,
              nameClaimedAt: info.connectedAt,
              address: info.address,
              tcpPort: 0,
              appVersion: '',
              firstSeen: info.connectedAt,
              lastSeen: now,
              online: true,
              sources: const {DiscoverySource.tcp},
            ),
            link: LinkState.connected,
            info: info,
          ),
    ]..sort(_byLinkThenName);

    final connected = peers.where((p) => p.link == LinkState.connected).length;
    final unreachable = peers.any((p) => p.link == LinkState.unreachable);
    final status = switch (discovery.state) {
      LanState.blocked => NearbyStatus.blocked,
      LanState.noNetwork => NearbyStatus.noNetwork,
      _ when connected > 0 => NearbyStatus.connected,
      _ when unreachable => NearbyStatus.unreachable,
      _ => NearbyStatus.searching,
    };
    return NearbySnapshot(
      status: status,
      peers: peers,
      discovery: discovery,
      links: links,
    );
  }

  static const initial = NearbySnapshot(
    status: NearbyStatus.noNetwork,
    peers: [],
    discovery: DiscoverySnapshot.initial,
    links: LinksSnapshot.initial,
  );

  final NearbyStatus status;

  /// Connected first, then connecting, unreachable, offline; by name.
  final List<NearbyPeer> peers;
  final DiscoverySnapshot discovery;
  final LinksSnapshot links;

  int get connectedCount =>
      peers.where((p) => p.link == LinkState.connected).length;

  /// The first peer that is found but can't be reached, for the hint.
  NearbyPeer? get firstUnreachable {
    for (final p in peers) {
      if (p.link == LinkState.unreachable) return p;
    }
    return null;
  }

  /// Nobody reachable for a while on a working network (spec §31).
  bool get isolationSuspected =>
      discovery.isolationSuspected && connectedCount == 0;

  static int _byLinkThenName(NearbyPeer a, NearbyPeer b) {
    final byLink = a.link.index.compareTo(b.link.index);
    if (byLink != 0) return byLink;
    return Username.key(a.peer.name).compareTo(Username.key(b.peer.name));
  }
}
