import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';

/// What Bluetooth is doing, for the status card.
enum BluetoothPhase {
  unsupported,
  off,
  needsPermission,
  locationOff,

  /// Advertising and scanning.
  searching,
}

final class BluetoothStatus {
  const BluetoothStatus(this.phase, {this.nearby = 0});

  final BluetoothPhase phase;

  /// LinkUp phones seen recently.
  final int nearby;

  @override
  bool operator ==(Object other) =>
      other is BluetoothStatus &&
      other.phase == phase &&
      other.nearby == nearby;

  @override
  int get hashCode => Object.hash(phase, nearby);
}

/// Finds LinkUp phones over Bluetooth LE (P14) and hands them to the
/// connection manager as endpoints (address and channel). Connecting,
/// the handshake and messages are the same as over Wi-Fi.
final class BluetoothController {
  BluetoothController({
    required this._platform,
    required this._deviceId,
    required this._logger,
  });

  /// A phone not heard from for this long is forgotten.
  static const peerExpiry = Duration(seconds: 45);
  static const tickInterval = Duration(seconds: 3);

  final Bluetooth _platform;
  final String Function() _deviceId;
  final AppLogger _logger;

  final Map<String, (BtFound, DateTime)> _peers = {};
  final StreamController<BluetoothStatus> _changes =
      StreamController.broadcast();
  final StreamController<List<PeerEndpoint>> _endpoints =
      StreamController.broadcast();
  final List<StreamSubscription<Object>> _subscriptions = [];

  bool _supported = true;
  bool _running = false;
  bool _enabled = false;
  bool _discovering = false;
  BtPermission _permission = BtPermission.denied;
  int? _channel;
  Timer? _tick;

  BluetoothStatus _current = const BluetoothStatus(BluetoothPhase.searching);
  BluetoothStatus get current => _current;
  Stream<BluetoothStatus> get changes => _changes.stream;

  /// The current status, then every change, with nothing missed between.
  Stream<BluetoothStatus> watch() => Stream.multi((listener) {
    listener.add(_current);
    final subscription = _changes.stream.listen(listener.add);
    listener.onCancel = subscription.cancel;
  });

  /// Phones to connect to; a new list on every change.
  Stream<List<PeerEndpoint>> get endpoints => _endpoints.stream;

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
      ..add(
        _platform.enabledChanges.listen((on) {
          _enabled = on;
          if (!on) _discovering = false;
          unawaited(_step());
        }),
      );
    _enabled = await _platform.isEnabled();
    _permission = await _platform.permission();
    _tick = Timer.periodic(tickInterval, (_) => unawaited(_step()));
    await _step();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _tick?.cancel();
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    if (_supported && _discovering) await _platform.stopDiscovery();
    _discovering = false;
  }

  /// The control server's channel, or null until it could be opened.
  int? get channel => _channel;

  /// Ready to open a server and advertise: allowed, and Bluetooth is on.
  bool get ready =>
      _supported && _enabled && _permission == BtPermission.granted;

  /// The control server's channel, once listening; advertised to others.
  void setChannel(int? channel) {
    if (channel == _channel) return;
    _channel = channel;
    _discovering = false; // advertise the new channel
    unawaited(_step());
  }

  Future<void> requestPermission() async {
    await _platform.requestPermission();
    _permission = await _platform.permission();
    await _step();
  }

  Future<void> requestEnable() => _platform.requestEnable();

  Future<void> openLocationSettings() => _platform.openLocationSettings();

  void _onFound(BtFound peer) {
    if (peer.deviceId == _deviceId()) return;
    final known = _peers[peer.deviceId]?.$1;
    _peers[peer.deviceId] = (peer, clock.now());
    final changed =
        known == null ||
        known.address != peer.address ||
        known.channel != peer.channel;
    if (changed) _publish();
    _emit();
  }

  Future<void> _step() async {
    if (!_running || !_supported) return;
    if (_permission != BtPermission.granted) {
      _permission = await _platform.permission();
    }
    final now = clock.now();
    final before = _peers.length;
    _peers.removeWhere((_, entry) => now.difference(entry.$2) > peerExpiry);
    if (_peers.length != before) _publish();
    final channel = _channel;
    final ready =
        _enabled && _permission == BtPermission.granted && channel != null;
    if (ready && !_discovering) {
      _discovering = true;
      _logger.info(LogTag.network, 'Bluetooth discovery started', {
        'channel': channel,
      });
      try {
        await _platform.startDiscovery(_deviceId(), channel);
      } on PlatformException catch (e) {
        _discovering = false;
        _logger.warning(LogTag.network, 'Bluetooth discovery refused', {
          'reason': e.code,
        });
      }
    }
    _emit();
  }

  void _publish() {
    if (_endpoints.isClosed) return;
    _endpoints.add([
      for (final (peer, _) in _peers.values)
        PeerEndpoint(
          deviceId: peer.deviceId,
          address: peer.address,
          port: peer.channel,
        ),
    ]);
  }

  void _emit() {
    final next = _status();
    if (next == _current || _changes.isClosed) return;
    _current = next;
    _changes.add(next);
  }

  BluetoothStatus _status() {
    if (!_supported) return const BluetoothStatus(BluetoothPhase.unsupported);
    if (_permission == BtPermission.denied) {
      return const BluetoothStatus(BluetoothPhase.needsPermission);
    }
    if (_permission == BtPermission.locationOff) {
      return const BluetoothStatus(BluetoothPhase.locationOff);
    }
    if (!_enabled) return const BluetoothStatus(BluetoothPhase.off);
    return BluetoothStatus(BluetoothPhase.searching, nearby: _peers.length);
  }
}
