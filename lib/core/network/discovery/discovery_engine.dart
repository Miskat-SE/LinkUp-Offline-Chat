import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/discovery/datagram_transport.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/discovery/peer_registry.dart';
import 'package:resqmesh/core/network/discovery/service_discovery.dart';
import 'package:resqmesh/core/network/network_monitor.dart';
import 'package:resqmesh/core/network/network_snapshot.dart';
import 'package:resqmesh/core/network/protocol/datagram.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

/// What this device announces about itself.
final class SelfInfo {
  const SelfInfo({
    required this.deviceId,
    this.name,
    this.nameClaimedAt,
    this.announce = false,
    this.appVersion = '',
  });

  final String deviceId;
  final String? name;
  final DateTime? nameClaimedAt;

  /// Whether the user chose a LAN connection method (Wi-Fi or hotspot).
  final bool announce;
  final String appVersion;

  bool get canAnnounce => announce && name != null && nameClaimedAt != null;

  String get shortId => deviceId.substring(0, 4);
}

/// The status line users see (spec §6, PROJECT_PLAN.md §6.5).
enum LanState {
  /// No Wi-Fi joined and no hotspot shared.
  noNetwork,

  /// On a local network, nobody found yet.
  searching,

  /// At least one other device online.
  connected,

  /// Android refused local network access (EPERM).
  blocked,
}

/// Another online device keeps this device's name (PROTOCOL.md §4.2).
final class NameClash {
  const NameClash({required this.holderId, required this.holderName});

  final String holderId;
  final String holderName;
}

/// Counters for the developer screen (spec §34).
final class DiscoveryStats {
  const DiscoveryStats({
    this.sent = const {},
    this.received = const {},
    this.malformed = 0,
    this.foreign = 0,
    this.recentErrors = const [],
  });

  /// Datagrams sent and received, by packet type.
  final Map<String, int> sent;
  final Map<String, int> received;

  /// ResQMesh datagrams that failed validation.
  final int malformed;

  /// Other apps' datagrams on our port.
  final int foreign;
  final List<String> recentErrors;
}

final class DiscoverySnapshot {
  const DiscoverySnapshot({
    required this.state,
    required this.network,
    required this.peers,
    required this.isolationSuspected,
    required this.clash,
    required this.stats,
    required this.udpPort,
    required this.nsdEnabled,
  });

  static const initial = DiscoverySnapshot(
    state: LanState.noNetwork,
    network: NetworkSnapshot.none,
    peers: [],
    isolationSuspected: false,
    clash: null,
    stats: DiscoveryStats(),
    udpPort: null,
    nsdEnabled: false,
  );

  final LanState state;
  final NetworkSnapshot network;

  /// Every device seen this session, online first.
  final List<Peer> peers;

  /// On a LAN for a while and nobody found: the router may block
  /// device-to-device traffic (spec §31).
  final bool isolationSuspected;
  final NameClash? clash;
  final DiscoveryStats stats;

  /// The bound UDP port, or null if discovery couldn't bind.
  final int? udpPort;
  final bool nsdEnabled;

  int get onlineCount => peers.where((p) => p.online).length;
}

enum NameCheckOutcome {
  available,
  taken,

  /// No local network, so nobody could be asked (spec §5 still allows it).
  unverified,
}

final class NameCheckResult {
  const NameCheckResult(this.outcome);

  final NameCheckOutcome outcome;
}

/// Finds other ResQMesh devices on the local network with UDP broadcast and
/// NSD, keeps the peer list, and checks that names are unique
/// (PROJECT_PLAN.md §6, PROTOCOL.md §4.1–4.2).
final class DiscoveryEngine {
  DiscoveryEngine({
    required this._network,
    required this._bindUdp,
    required this._logger,
    required this._self,
    ServiceDiscovery? serviceDiscovery,
    this._udpPort = ProtocolConstants.udpPort,
    this._tcpPort = ProtocolConstants.tcpPort,
    Random? random,
  }) : _nsd = serviceDiscovery,
       _random = random ?? Random();

  final NetworkMonitor _network;
  final DatagramBinder _bindUdp;
  final AppLogger _logger;
  final ServiceDiscovery? _nsd;
  final int _udpPort;
  int _tcpPort;
  final Random _random;
  SelfInfo _self;

  final PeerRegistry _registry = PeerRegistry(
    offlineAfter: DiscoveryTiming.offlineAfter,
  );
  final StreamController<DiscoverySnapshot> _snapshots =
      StreamController<DiscoverySnapshot>.broadcast();
  DiscoverySnapshot _current = DiscoverySnapshot.initial;

  NetworkSnapshot _net = NetworkSnapshot.none;
  DatagramTransport? _udp;
  StreamSubscription<ReceivedDatagram>? _udpSubscription;
  StreamSubscription<NetworkSnapshot>? _networkSubscription;
  StreamSubscription<ServiceCandidate>? _nsdSubscription;
  Timer? _helloTimer;
  Timer? _expiryTimer;
  bool _started = false;
  bool _blocked = false;
  bool _nsdEnabled = false;
  DateTime? _searchingSince;
  NameClash? _clash;
  final Set<String> _nsdHints = {};
  final List<_PendingCheck> _pendingChecks = [];
  Future<void> _queue = Future.value();

  final Map<String, int> _sent = {};
  final Map<String, int> _received = {};
  int _malformed = 0;
  int _foreign = 0;
  final List<String> _errors = [];

  DiscoverySnapshot get current => _current;

  Stream<DiscoverySnapshot> get snapshots => _snapshots.stream;

  SelfInfo get self => _self;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _networkSubscription = _network.changes.listen(
      (net) => _serial(() => _applyNetwork(net)),
    );
    _nsdSubscription = _nsd?.candidates.listen(_onCandidate);
    _expiryTimer = Timer.periodic(DiscoveryTiming.expiryCheck, (_) => _tick());
    try {
      await _network.start();
    } on Exception catch (e) {
      _error('Network monitor failed: ${e.runtimeType}');
    }
    await _serial(() => _applyNetwork(_network.current));
  }

  /// Says GOODBYE and releases sockets, timers and locks.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _helloTimer?.cancel();
    _expiryTimer?.cancel();
    await _serial(() async {
      if (_self.canAnnounce) _broadcast(_goodbye('appStopped'));
      await _closeUdp();
      await _nsd?.stop();
      _nsdEnabled = false;
    });
    unawaited(_networkSubscription?.cancel());
    unawaited(_nsdSubscription?.cancel());
    for (final check in _pendingChecks) {
      check.complete(NameCheckOutcome.unverified);
    }
    _pendingChecks.clear();
    try {
      await _network.setMulticastLock(held: false);
      await _network.stop();
    } on Exception {
      // Shutting down; nothing left to do.
    }
  }

  Future<void> dispose() async {
    await stop();
    await _snapshots.close();
  }

  /// Updates what this device announces. A new name or claim is announced
  /// straight away.
  void updateSelf(SelfInfo self) {
    final previous = _self;
    _self = self;
    final changed =
        previous.name != self.name ||
        previous.nameClaimedAt != self.nameClaimedAt ||
        previous.announce != self.announce;
    if (!changed) return;
    unawaited(
      _serial(() async {
        await _updateAdvertising();
        if (self.canAnnounce) {
          _broadcast(_hello());
        } else if (previous.canAnnounce) {
          _broadcast(_goodbye('stoppedAnnouncing'));
        }
        _recomputeClash();
        _emit();
      }),
    );
  }

  /// Announces the TCP port actually listened on (P3), which may differ
  /// from the preferred one if it was taken.
  void setTcpPort(int port) {
    if (port == _tcpPort) return;
    _tcpPort = port;
    unawaited(
      _serial(() async {
        await _nsd?.stopAdvertising();
        await _updateAdvertising();
        if (_self.canAnnounce) _broadcast(_hello());
      }),
    );
  }

  /// A connected device renamed itself over TCP (REGISTER).
  void applyRename(String deviceId, String name, DateTime nameClaimedAt) {
    if (!_registry.rename(deviceId, name, nameClaimedAt)) return;
    _logger.info(LogTag.discovery, 'Peer renamed', {
      'device': deviceId.substring(0, 4),
    });
    _recomputeClash();
    _emit();
  }

  /// Sends HELLO now (developer screen) and asks who is there.
  void announceNow() {
    _broadcast(DiscoveryPacket(_header()));
    if (_self.canAnnounce) _broadcast(_hello());
  }

  /// Checks [name] (already normalised and valid) against online peers and
  /// asks the network for [DiscoveryTiming.nameCheckWait] (spec §5).
  Future<NameCheckResult> checkName(String name) async {
    if (_registry.onlineHolderOf(name, exceptId: _self.deviceId) != null) {
      return const NameCheckResult(NameCheckOutcome.taken);
    }
    if (_udp == null || !_net.hasLan) {
      return const NameCheckResult(NameCheckOutcome.unverified);
    }
    final check = _PendingCheck(name);
    _pendingChecks.add(check);
    _broadcast(NameCheckPacket(_header(), candidateName: name));
    final timer = Timer(
      DiscoveryTiming.nameCheckWait,
      () => check.complete(NameCheckOutcome.available),
    );
    final outcome = await check.future;
    timer.cancel();
    _pendingChecks.remove(check);
    return NameCheckResult(outcome);
  }

  // ---------------------------------------------------------------- network

  Future<void> _applyNetwork(NetworkSnapshot net) async {
    final previous = _net;
    _net = net;
    if (!net.hasLan) {
      if (previous.hasLan) {
        _logger.info(LogTag.network, 'Local network lost');
      }
      _helloTimer?.cancel();
      await _closeUdp();
      await _nsd?.stop();
      _nsdEnabled = false;
      _registry.markAllOffline();
      _blocked = false;
      try {
        await _network.setMulticastLock(held: false);
      } on Exception {
        // Not fatal.
      }
      _emit();
      return;
    }

    final interfacesChanged = !_sameInterfaces(previous, net);
    if (interfacesChanged || _udp == null) {
      _logger.info(LogTag.network, 'Local network up', {
        'interfaces': net.interfaces.join(', '),
        'boundToWifi': net.boundToWifi,
      });
      // Sockets made before the process was rebound would still use the
      // old network, so start over (PROJECT_PLAN.md §5.5 rule 10).
      await _closeUdp();
      await _openUdp();
      try {
        await _network.setMulticastLock(held: true);
      } on Exception catch (e) {
        _error('Multicast lock failed: ${e.runtimeType}');
      }
      final nsd = _nsd;
      if (nsd != null) {
        await nsd.startBrowsing();
        _nsdEnabled = true;
      }
      await _updateAdvertising();
      _broadcast(DiscoveryPacket(_header()));
      _scheduleHello(immediately: true);
    }
    _emit();
  }

  static bool _sameInterfaces(NetworkSnapshot a, NetworkSnapshot b) {
    if (a.interfaces.length != b.interfaces.length) return false;
    for (var i = 0; i < a.interfaces.length; i++) {
      if (a.interfaces[i] != b.interfaces[i]) return false;
    }
    return true;
  }

  Future<void> _openUdp() async {
    try {
      final udp = await _bindUdp(_udpPort);
      _udp = udp;
      _blocked = false;
      _udpSubscription = udp.incoming.listen(
        _onDatagram,
        onError: (Object e) => _error('UDP receive failed: ${e.runtimeType}'),
      );
    } on SocketException catch (e) {
      _handleSocketError('UDP bind', e);
    }
  }

  Future<void> _closeUdp() async {
    // Cancelling stops events at once; its future only reports cleanup.
    unawaited(_udpSubscription?.cancel());
    _udpSubscription = null;
    final udp = _udp;
    _udp = null;
    await udp?.close();
  }

  Future<void> _updateAdvertising() async {
    final nsd = _nsd;
    if (nsd == null) return;
    if (_net.hasLan && _self.canAnnounce) {
      await nsd.advertise(deviceId: _self.deviceId, port: _tcpPort);
    } else {
      await nsd.stopAdvertising();
    }
  }

  // ---------------------------------------------------------------- sending

  PacketHeader _header({String receiverId = PacketHeader.everyone}) =>
      PacketHeader.create(
        senderId: _self.deviceId,
        senderName: _self.name ?? '',
        receiverId: receiverId,
      );

  Announcement _announcement() => Announcement(
    tcpPort: _tcpPort,
    appVersion: _self.appVersion,
    nameClaimedAt: _self.nameClaimedAt!,
  );

  HelloPacket _hello() => HelloPacket(_header(), _announcement());

  GoodbyePacket _goodbye(String reason) =>
      GoodbyePacket(_header(), reason: reason);

  void _broadcast(Packet packet) {
    final data = DatagramCodec.encode(packet);
    for (final target in _net.broadcastTargets) {
      _sendTo(data, target, _udpPort, packet.type);
    }
  }

  void _unicast(Packet packet, String address, int port) =>
      _sendTo(DatagramCodec.encode(packet), address, port, packet.type);

  void _sendTo(Uint8List data, String address, int port, String type) {
    final udp = _udp;
    if (udp == null) return;
    try {
      udp.send(data, address, port);
      _sent[type] = (_sent[type] ?? 0) + 1;
    } on SocketException catch (e) {
      _handleSocketError('UDP send to $address', e);
    }
  }

  void _scheduleHello({bool immediately = false}) {
    _helloTimer?.cancel();
    if (immediately && _self.canAnnounce) _broadcast(_hello());
    final jitter = DiscoveryTiming.helloJitter.inMilliseconds;
    final delay =
        DiscoveryTiming.helloInterval +
        Duration(milliseconds: _random.nextInt(2 * jitter + 1) - jitter);
    _helloTimer = Timer(delay, () {
      if (_udp == null) return;
      _scheduleHello(immediately: true);
    });
  }

  // -------------------------------------------------------------- receiving

  void _onDatagram(ReceivedDatagram datagram) {
    switch (DatagramCodec.decode(datagram.data)) {
      case Foreign():
        _foreign++;
      case Malformed(:final reason):
        _malformed++;
        _logger.debug(LogTag.discovery, 'Malformed datagram', {
          'from': datagram.address,
          'reason': reason,
        });
      case TooLarge() || UnsupportedVersion() || UnknownType():
        _malformed++;
      case Decoded(:final packet):
        // Our own broadcasts come back to us.
        if (packet.header.senderId == _self.deviceId) return;
        _received[packet.type] = (_received[packet.type] ?? 0) + 1;
        _handle(packet, datagram.address, datagram.port);
    }
    _emit();
  }

  void _handle(Packet packet, String address, int port) {
    switch (packet) {
      case DiscoveryPacket():
        if (!_self.canAnnounce) return;
        final delay = Duration(
          milliseconds: _random.nextInt(
            DiscoveryTiming.maxResponseDelay.inMilliseconds + 1,
          ),
        );
        Timer(delay, () {
          if (!_self.canAnnounce) return;
          _unicast(
            DiscoveryResponsePacket(
              _header(receiverId: packet.header.senderId),
              _announcement(),
            ),
            address,
            port,
          );
        });
      case DiscoveryResponsePacket(:final announcement) ||
          HelloPacket(:final announcement):
        _observe(packet.header, announcement, address);
      case GoodbyePacket():
        final peer = _registry[packet.header.senderId];
        if (_registry.goodbye(packet.header.senderId, clock.now())) {
          _logger.info(LogTag.discovery, 'Peer left', {
            'device': peer?.shortId,
            'reason': packet.reason,
          });
          _recomputeClash();
        }
      case NameCheckPacket(:final candidateName):
        final name = _self.name;
        if (!_self.canAnnounce || name == null) return;
        if (!Username.same(candidateName, name)) return;
        _unicast(
          RegisterResponsePacket(
            _header(receiverId: packet.header.senderId),
            result: RegisterResult.nameTaken,
            name: name,
            holderId: _self.deviceId,
            holderClaimedAt: _self.nameClaimedAt,
          ),
          address,
          port,
        );
      case RegisterResponsePacket(:final result, :final name):
        if (result == RegisterResult.nameTaken) _nameTaken(name);
      case RegisterPacket() || PingPacket() || PongPacket():
        // TCP-only packets; ignored if they arrive over UDP.
        break;
    }
  }

  void _observe(
    PacketHeader header,
    Announcement announcement,
    String address,
  ) {
    if (!announcement.compatible) return;
    final update = _registry.observe(
      deviceId: header.senderId,
      name: header.senderName,
      nameClaimedAt: announcement.nameClaimedAt,
      address: address,
      tcpPort: announcement.tcpPort,
      appVersion: announcement.appVersion,
      source: _nsdHints.contains(header.senderId)
          ? DiscoverySource.nsd
          : DiscoverySource.udp,
      now: clock.now(),
    );
    final short = header.senderId.substring(0, 4);
    switch (update) {
      case PeerUpdate.added:
        _logger.info(LogTag.discovery, 'Peer found', {
          'device': short,
          'address': address,
        });
      case PeerUpdate.cameOnline:
        _logger.info(LogTag.discovery, 'Peer back online', {'device': short});
      case PeerUpdate.changed:
        _logger.info(LogTag.discovery, 'Peer updated', {
          'device': short,
          'address': address,
        });
      case PeerUpdate.refreshed:
        break;
    }
    _nameTaken(header.senderName);
    _recomputeClash();
  }

  void _onCandidate(ServiceCandidate candidate) {
    if (candidate.deviceId == _self.deviceId) return;
    _nsdHints.add(candidate.deviceId);
    final known = _registry[candidate.deviceId];
    if (known != null && known.online && known.address == candidate.address) {
      return;
    }
    // NSD only says where to look; ask that address directly.
    _logger.debug(LogTag.discovery, 'NSD candidate', {
      'device': candidate.deviceId.substring(0, 4),
      'address': candidate.address,
    });
    _unicast(DiscoveryPacket(_header()), candidate.address, _udpPort);
  }

  void _nameTaken(String name) {
    for (final check in _pendingChecks) {
      if (Username.same(check.name, name)) {
        check.complete(NameCheckOutcome.taken);
      }
    }
  }

  // ------------------------------------------------------------------ state

  void _tick() {
    final gone = _registry.expire(clock.now());
    for (final peer in gone) {
      _logger.info(LogTag.discovery, 'Peer lost', {'device': peer.shortId});
    }
    if (gone.isNotEmpty) _recomputeClash();
    _emit();
  }

  void _recomputeClash() {
    NameClash? clash;
    final name = _self.name;
    final claimedAt = _self.nameClaimedAt;
    if (name != null && claimedAt != null) {
      for (final peer in _registry.online) {
        if (!Username.same(peer.name, name)) continue;
        final keepsName = Peer.winsNameClash(
          claimedAt: claimedAt,
          deviceId: _self.deviceId,
          otherClaimedAt: peer.nameClaimedAt,
          otherId: peer.deviceId,
        );
        if (!keepsName) {
          clash = NameClash(holderId: peer.deviceId, holderName: peer.name);
          break;
        }
      }
    }
    if (clash != null && _clash?.holderId != clash.holderId) {
      _logger.warning(LogTag.discovery, 'Name used by another device', {
        'holder': clash.holderId.substring(0, 4),
      });
    }
    _clash = clash;
  }

  void _handleSocketError(String action, SocketException e) {
    final code = e.osError?.errorCode;
    // EPERM / EACCES: Android blocked local network access.
    if (code == 1 || code == 13) {
      if (!_blocked) {
        _logger.error(LogTag.network, 'Local network access blocked', {
          'action': action,
        });
      }
      _blocked = true;
    } else {
      _error('$action failed: ${e.osError?.message ?? e.message}');
    }
  }

  void _error(String message) {
    _logger.error(LogTag.network, message);
    _errors.add('${clock.now().toIso8601String().substring(11, 19)} $message');
    if (_errors.length > 20) _errors.removeAt(0);
  }

  void _emit() {
    final now = clock.now();
    final online = _registry.online.length;
    final state = switch (_net) {
      _ when _blocked => LanState.blocked,
      NetworkSnapshot(hasLan: false) => LanState.noNetwork,
      _ when online > 0 => LanState.connected,
      _ => LanState.searching,
    };
    if (state == LanState.searching) {
      _searchingSince ??= now;
    } else {
      _searchingSince = null;
    }
    final since = _searchingSince;
    _current = DiscoverySnapshot(
      state: state,
      network: _net,
      peers: _registry.all,
      isolationSuspected:
          since != null &&
          now.difference(since) >= DiscoveryTiming.isolationHintAfter,
      clash: _clash,
      stats: DiscoveryStats(
        sent: Map.unmodifiable(_sent),
        received: Map.unmodifiable(_received),
        malformed: _malformed,
        foreign: _foreign,
        recentErrors: List.unmodifiable(_errors),
      ),
      udpPort: _udp == null ? null : _udpPort,
      nsdEnabled: _nsdEnabled,
    );
    if (!_snapshots.isClosed) _snapshots.add(_current);
  }

  /// Runs network changes one at a time.
  Future<void> _serial(Future<void> Function() action) {
    final next = _queue.then((_) => action()).catchError((Object e) {
      _error('Discovery step failed: ${e.runtimeType}');
    });
    _queue = next;
    return next;
  }
}

final class _PendingCheck {
  _PendingCheck(this.name);

  final String name;
  final Completer<NameCheckOutcome> _completer = Completer();

  Future<NameCheckOutcome> get future => _completer.future;

  void complete(NameCheckOutcome outcome) {
    if (!_completer.isCompleted) _completer.complete(outcome);
  }
}
