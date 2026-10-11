import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// A LinkUp phone found through Wi-Fi Direct service discovery.
final class P2pPeer {
  const P2pPeer({
    required this.deviceAddress,
    required this.deviceId,
    required this.name,
    required this.hosting,
    this.networkName,
    this.passphrase,
  });

  /// Wi-Fi Direct MAC address.
  final String deviceAddress;
  final String deviceId;
  final String name;

  /// It owns a group others can join.
  final bool hosting;
  final String? networkName;
  final String? passphrase;
}

/// This phone's Wi-Fi Direct group state.
final class P2pGroup {
  const P2pGroup({
    required this.enabled,
    required this.formed,
    this.isOwner = false,
    this.clients = 0,
    this.networkName,
    this.passphrase,
  });

  static const unknown = P2pGroup(enabled: true, formed: false);

  /// Wi-Fi is on.
  final bool enabled;

  /// This phone is in a group.
  final bool formed;
  final bool isOwner;

  /// Phones joined, when [isOwner].
  final int clients;
  final String? networkName;
  final String? passphrase;
}

enum P2pPermission { granted, denied, locationOff }

/// Android Wi-Fi Direct (ADR-0023), behind an interface for tests.
abstract interface class WifiDirect {
  Stream<P2pPeer> get found;
  Stream<P2pGroup> get groups;

  Future<bool> isSupported();
  Future<P2pPermission> permission();

  /// Shows Android's permission dialog; true when granted.
  Future<bool> requestPermission();
  Future<void> openLocationSettings();

  /// Advertises this phone and looks for others. Called again after a
  /// rename or once permission is granted.
  Future<void> start({required String deviceId, required String name});
  Future<void> stop();
  Future<void> advertise({
    required bool hosting,
    String? networkName,
    String? passphrase,
  });

  /// These throw [PlatformException] when Android refuses.
  Future<void> createGroup(String networkName, String passphrase);
  Future<void> joinGroup(P2pPeer host);
  Future<void> leaveGroup();
}

/// [WifiDirect] backed by the Kotlin bridge (`WifiDirectBridge.kt`).
final class PlatformWifiDirect implements WifiDirect, WifiDirectFlutterApi {
  PlatformWifiDirect({WifiDirectHostApi? host})
    : _host = host ?? WifiDirectHostApi();

  final WifiDirectHostApi _host;
  final StreamController<P2pPeer> _found = StreamController.broadcast();
  final StreamController<P2pGroup> _groups = StreamController.broadcast();

  @override
  Stream<P2pPeer> get found => _found.stream;

  @override
  Stream<P2pGroup> get groups => _groups.stream;

  @override
  Future<bool> isSupported() => _host.isSupported();

  @override
  Future<P2pPermission> permission() async =>
      switch (await _host.permissionState()) {
        'granted' => P2pPermission.granted,
        'locationOff' => P2pPermission.locationOff,
        _ => P2pPermission.denied,
      };

  @override
  Future<bool> requestPermission() => _host.requestPermission();

  @override
  Future<void> openLocationSettings() => _host.openLocationSettings();

  @override
  Future<void> start({required String deviceId, required String name}) {
    WifiDirectFlutterApi.setUp(this);
    return _host.start(deviceId, name);
  }

  @override
  Future<void> stop() async {
    WifiDirectFlutterApi.setUp(null);
    try {
      await _host.stop();
    } on PlatformException {
      // The engine may already be detached while the app shuts down.
    }
  }

  @override
  Future<void> advertise({
    required bool hosting,
    String? networkName,
    String? passphrase,
  }) => _host.advertise(hosting, networkName, passphrase);

  @override
  Future<void> createGroup(String networkName, String passphrase) =>
      _host.createGroup(networkName, passphrase);

  @override
  Future<void> joinGroup(P2pPeer host) =>
      _host.joinGroup(host.deviceAddress, host.networkName, host.passphrase);

  @override
  Future<void> leaveGroup() => _host.leaveGroup();

  @override
  void onServiceFound(WifiDirectService service) => _found.add(
    P2pPeer(
      deviceAddress: service.deviceAddress,
      deviceId: service.deviceId,
      name: service.name,
      hosting: service.hosting,
      networkName: service.networkName,
      passphrase: service.passphrase,
    ),
  );

  @override
  void onGroupChanged(WifiDirectGroup group) => _groups.add(
    P2pGroup(
      enabled: group.enabled,
      formed: group.formed,
      isOwner: group.isOwner,
      clients: group.clients,
      networkName: group.networkName,
      passphrase: group.passphrase,
    ),
  );
}
