import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// A LinkUp phone found by Bluetooth LE scanning.
final class BtFound {
  const BtFound({
    required this.address,
    required this.deviceId,
    required this.channel,
  });

  final String address;
  final String deviceId;

  /// L2CAP channel its control connections are accepted on.
  final int channel;
}

/// What happens on Bluetooth links, in the order it happened.
sealed class BtLinkEvent {
  const BtLinkEvent(this.linkId);
  final int linkId;
}

/// A link accepted by the server on [channel].
final class BtLinkOpened extends BtLinkEvent {
  const BtLinkOpened(super.linkId, this.address, this.channel);
  final String address;
  final int channel;
}

final class BtData extends BtLinkEvent {
  const BtData(super.linkId, this.bytes);
  final Uint8List bytes;
}

final class BtLinkClosed extends BtLinkEvent {
  const BtLinkClosed(super.linkId);
}

enum BtPermission { granted, denied, locationOff }

/// Android Bluetooth for LinkUp (P14), behind an interface for tests.
abstract interface class Bluetooth {
  Stream<BtFound> get found;
  Stream<BtLinkEvent> get links;
  Stream<bool> get enabledChanges;

  Future<bool> isSupported();
  Future<BtPermission> permission();
  Future<bool> requestPermission();
  Future<bool> isEnabled();
  Future<void> requestEnable();
  Future<void> openLocationSettings();

  /// Opens an L2CAP server; its channel.
  Future<int> openServer();
  Future<void> closeServer(int channel);

  /// Advertises this phone and its control [channel], and scans.
  Future<void> startDiscovery(String deviceId, int channel);
  Future<void> stopDiscovery();

  /// Opens a link; its ID. Throws [PlatformException] when unreachable.
  Future<int> connect(String address, int channel);
  void send(int linkId, Uint8List bytes);
  void closeLink(int linkId);
}

/// [Bluetooth] backed by the Kotlin bridge (`BluetoothBridge.kt`).
final class PlatformBluetooth implements Bluetooth, BluetoothFlutterApi {
  PlatformBluetooth({BluetoothHostApi? host})
    : _host = host ?? BluetoothHostApi() {
    BluetoothFlutterApi.setUp(this);
  }

  final BluetoothHostApi _host;
  final StreamController<BtFound> _found = StreamController.broadcast();
  final StreamController<BtLinkEvent> _links = StreamController.broadcast(
    sync: true,
  );
  final StreamController<bool> _enabled = StreamController.broadcast();

  @override
  Stream<BtFound> get found => _found.stream;

  @override
  Stream<BtLinkEvent> get links => _links.stream;

  @override
  Stream<bool> get enabledChanges => _enabled.stream;

  @override
  Future<bool> isSupported() => _host.isSupported();

  @override
  Future<BtPermission> permission() async =>
      switch (await _host.permissionState()) {
        'granted' => BtPermission.granted,
        'locationOff' => BtPermission.locationOff,
        _ => BtPermission.denied,
      };

  @override
  Future<bool> requestPermission() => _host.requestPermission();

  @override
  Future<bool> isEnabled() => _host.isEnabled();

  @override
  Future<void> requestEnable() => _host.requestEnable();

  @override
  Future<void> openLocationSettings() => _host.openLocationSettings();

  @override
  Future<int> openServer() => _host.openServer();

  @override
  Future<void> closeServer(int channel) => _host.closeServer(channel);

  @override
  Future<void> startDiscovery(String deviceId, int channel) =>
      _host.startDiscovery(deviceId, channel);

  @override
  Future<void> stopDiscovery() => _host.stopDiscovery();

  @override
  Future<int> connect(String address, int channel) =>
      _host.connect(address, channel);

  @override
  void send(int linkId, Uint8List bytes) =>
      unawaited(_host.send(linkId, bytes).catchError((Object _) {}));

  @override
  void closeLink(int linkId) =>
      unawaited(_host.closeLink(linkId).catchError((Object _) {}));

  @override
  void onPeerFound(BtPeer peer) => _found.add(
    BtFound(
      address: peer.address,
      deviceId: peer.deviceId,
      channel: peer.channel,
    ),
  );

  @override
  void onLinkOpened(int linkId, String address, int channel) =>
      _links.add(BtLinkOpened(linkId, address, channel));

  @override
  void onData(int linkId, Uint8List bytes) => _links.add(BtData(linkId, bytes));

  @override
  void onLinkClosed(int linkId) => _links.add(BtLinkClosed(linkId));

  @override
  void onEnabledChanged(bool enabled) => _enabled.add(enabled);
}
