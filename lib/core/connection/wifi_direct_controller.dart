import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';

/// What Wi-Fi Direct is doing, for the status card.
enum WifiDirectPhase {
  unsupported,
  wifiOff,
  needsPermission,
  locationOff,

  /// Looking for LinkUp phones; no group yet.
  searching,

  /// Creating a group or joining one.
  connecting,

  /// This phone owns the group.
  hosting,

  /// This phone joined another phone's group.
  joined,
}

final class WifiDirectStatus {
  const WifiDirectStatus(
    this.phase, {
    this.hostName,
    this.clients = 0,
    this.nearby = 0,
  });

  final WifiDirectPhase phase;

  /// The group owner's name, when joining or joined.
  final String? hostName;

  /// Phones in this phone's group, when hosting.
  final int clients;

  /// LinkUp phones seen recently.
  final int nearby;

  @override
  bool operator ==(Object other) =>
      other is WifiDirectStatus &&
      other.phase == phase &&
      other.hostName == hostName &&
      other.clients == clients &&
      other.nearby == nearby;

  @override
  int get hashCode => Object.hash(phase, hostName, clients, nearby);
}

/// A group's name and passphrase, worked out from its host's device ID, so
/// a phone that knows the host can join without finding the group itself:
/// a group owner can't be found by Wi-Fi Direct service discovery
/// (ADR-0023). Anyone running LinkUp can work them out, which matches the
/// v1.0 trust model (ADR-0022).
({String networkName, String passphrase}) groupCredentials(String hostId) => (
  networkName: 'DIRECT-LU-${shortId(hostId)}',
  passphrase: sha256
      .convert(utf8.encode('LinkUp Wi-Fi Direct 1|$hostId'))
      .toString()
      .substring(0, 24),
);

/// Forms Wi-Fi Direct groups by itself (ADR-0023). Phones advertise the
/// phones they have seen; two phones that have seen each other are
/// *mutual*. Among a phone and its mutual peers the lowest device ID hosts,
/// and the others join it with [groupCredentials]. Because the host waits
/// until its peers have seen it, they always know whom to join, even after
/// the host becomes impossible to find.
///
/// Once in a group, the normal LAN stack does the rest.
final class WifiDirectController {
  WifiDirectController({
    required this._platform,
    required this._self,
    required this._logger,
  });

  /// A phone not heard from for this long is forgotten.
  static const peerExpiry = Duration(minutes: 2);

  /// Creating or joining a group that hasn't formed by then is tried again.
  static const connectTimeout = Duration(seconds: 20);

  /// A host alone for this long, with nobody in sight, stops hosting.
  static const aloneLimit = Duration(minutes: 5);

  static const tickInterval = Duration(seconds: 3);

  final WifiDirect _platform;
  final ({String deviceId, String name}) Function() _self;
  final AppLogger _logger;

  final Map<String, (P2pPeer, DateTime)> _peers = {};
  final StreamController<WifiDirectStatus> _changes =
      StreamController.broadcast();
  final List<StreamSubscription<Object>> _subscriptions = [];

  P2pGroup _group = P2pGroup.unknown;
  P2pPermission _permission = P2pPermission.denied;
  bool _supported = true;
  bool _running = false;
  bool _busy = false;
  Timer? _tick;

  /// Set while creating or joining, until the group forms or it times out.
  ({P2pPeer? host, DateTime since})? _pending;
  DateTime? _aloneSince;

  /// The host this phone joined.
  String? _hostName;

  /// Short IDs last put in this phone's service record.
  List<String> _advertised = const [];

  WifiDirectStatus _current = const WifiDirectStatus(WifiDirectPhase.searching);
  WifiDirectStatus get current => _current;
  Stream<WifiDirectStatus> get changes => _changes.stream;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _supported = await _platform.isSupported();
    if (!_supported) {
      _emit();
      return;
    }
    _subscriptions
      ..add(_platform.found.listen(_onFound))
      ..add(_platform.groups.listen(_onGroup));
    _permission = await _platform.permission();
    await _startPlatform();
    _tick = Timer.periodic(tickInterval, (_) => unawaited(_step()));
    _emit();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _tick?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    if (_supported) await _platform.stop();
  }

  /// Shows Android's permission dialog.
  Future<void> requestPermission() async {
    await _platform.requestPermission();
    await _checkPermission();
  }

  Future<void> openLocationSettings() => _platform.openLocationSettings();

  /// The user changed their name: advertise the new one.
  Future<void> nameChanged() async {
    if (_running && _supported) await _startPlatform();
  }

  Future<void> _startPlatform() async {
    final self = _self();
    await _platform.start(deviceId: self.deviceId, name: self.name);
    _advertised = const [];
    await _advertiseSeen();
  }

  Future<void> _checkPermission() async {
    final before = _permission;
    _permission = await _platform.permission();
    // Advertising needs the permission, so start again once it is given.
    if (before != P2pPermission.granted &&
        _permission == P2pPermission.granted) {
      await _startPlatform();
    }
    _emit();
  }

  void _onFound(P2pPeer peer) {
    if (peer.deviceId == _self().deviceId) return;
    _peers[peer.deviceId] = (peer, clock.now());
    // Decided on the next tick, with everything seen by then.
    _emit();
  }

  void _onGroup(P2pGroup group) {
    _group = group;
    if (group.formed && !group.isOwner) {
      _hostName = _pending?.host?.name ?? _hostName;
    } else if (!group.formed) {
      _hostName = null;
    }
    if (group.formed) _pending = null;
    if (!group.formed || !group.isOwner || group.clients > 0) {
      _aloneSince = null;
    } else {
      _aloneSince ??= clock.now();
    }
    _emit();
    unawaited(_step());
  }

  /// One decision. Runs on every group change and every few seconds.
  Future<void> _step() async {
    if (!_running || _busy || !_supported) return;
    if (_permission != P2pPermission.granted) {
      await _checkPermission();
      return;
    }
    if (!_group.enabled) return;
    _busy = true;
    try {
      _forgetOld();
      await _advertiseSeen();
      final group = _group;
      if (group.formed && group.isOwner) {
        await _whileHosting(group);
      } else if (!group.formed) {
        await _whileAlone();
      }
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// Phones that have seen this phone, and that it has seen; lowest first.
  List<P2pPeer> _mutual() {
    final self = _self().deviceId;
    return [
      for (final (peer, _) in _peers.values)
        if (peer.hasSeen(self)) peer,
    ]..sort((a, b) => a.deviceId.compareTo(b.deviceId));
  }

  Future<void> _whileHosting(P2pGroup group) async {
    if (group.clients > 0) return;
    final self = _self().deviceId;
    final lower = _mutual().where((p) => p.deviceId.compareTo(self) < 0);
    final alone = _aloneSince;
    if (lower.isNotEmpty) {
      _logger.info(LogTag.network, 'Wi-Fi Direct: joining a lower host');
    } else if (alone == null ||
        _peers.isNotEmpty ||
        clock.now().difference(alone) < aloneLimit) {
      return;
    } else {
      _logger.info(LogTag.network, 'Wi-Fi Direct: alone, stopping the group');
    }
    await _try(_platform.leaveGroup);
  }

  Future<void> _whileAlone() async {
    final pending = _pending;
    if (pending != null) {
      if (clock.now().difference(pending.since) < connectTimeout) return;
      _logger.warning(LogTag.network, 'Wi-Fi Direct: group did not form');
      _pending = null;
    }
    final mutual = _mutual();
    if (mutual.isEmpty) return;
    final self = _self().deviceId;
    final host = mutual.first;
    if (self.compareTo(host.deviceId) < 0) {
      // This phone is the lowest: host.
      final credentials = groupCredentials(self);
      _pending = (host: null, since: clock.now());
      _logger.info(LogTag.network, 'Wi-Fi Direct: hosting a group');
      if (!await _try(
        () => _platform.createGroup(
          credentials.networkName,
          credentials.passphrase,
        ),
      )) {
        _pending = null;
      }
      return;
    }
    // The lowest is someone else: join them. Their group may not exist yet;
    // joining is simply tried again after the timeout.
    final credentials = groupCredentials(host.deviceId);
    _pending = (host: host, since: clock.now());
    _logger.info(LogTag.network, 'Wi-Fi Direct: joining', {
      'device': host.deviceId.substring(0, 4),
    });
    if (!await _try(
      () =>
          _platform.joinGroup(credentials.networkName, credentials.passphrase),
    )) {
      _pending = null;
    }
  }

  void _forgetOld() {
    final now = clock.now();
    _peers.removeWhere((_, entry) => now.difference(entry.$2) > peerExpiry);
  }

  /// Tells others which phones this one has seen, when that changes.
  Future<void> _advertiseSeen() async {
    final seen = [for (final id in _peers.keys) shortId(id)]..sort();
    if (_listEquals(seen, _advertised)) return;
    _advertised = seen;
    await _try(() => _platform.advertise(seen));
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _try(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on PlatformException catch (e) {
      _logger.warning(LogTag.network, 'Wi-Fi Direct step refused', {
        'reason': e.code,
      });
      return false;
    }
  }

  void _emit() {
    final next = _status();
    if (next == _current || _changes.isClosed) return;
    _current = next;
    _changes.add(next);
  }

  WifiDirectStatus _status() {
    final nearby = _peers.length;
    if (!_supported) return const WifiDirectStatus(WifiDirectPhase.unsupported);
    if (_permission == P2pPermission.denied) {
      return const WifiDirectStatus(WifiDirectPhase.needsPermission);
    }
    if (_permission == P2pPermission.locationOff) {
      return const WifiDirectStatus(WifiDirectPhase.locationOff);
    }
    if (!_group.enabled) return const WifiDirectStatus(WifiDirectPhase.wifiOff);
    final group = _group;
    if (group.formed && group.isOwner) {
      return WifiDirectStatus(
        WifiDirectPhase.hosting,
        clients: group.clients,
        nearby: nearby,
      );
    }
    if (group.formed) {
      return WifiDirectStatus(
        WifiDirectPhase.joined,
        hostName: _hostName,
        nearby: nearby,
      );
    }
    final pending = _pending;
    if (pending != null) {
      return WifiDirectStatus(
        WifiDirectPhase.connecting,
        hostName: pending.host?.name,
        nearby: nearby,
      );
    }
    return WifiDirectStatus(WifiDirectPhase.searching, nearby: nearby);
  }
}
