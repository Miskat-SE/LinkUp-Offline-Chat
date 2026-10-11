import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/platform/wifi_direct.dart';

/// A [WifiDirect] the test drives: it decides what is supported and
/// permitted, reports phones and group changes, and records requests.
final class FakeWifiDirect implements WifiDirect {
  bool supported = true;
  P2pPermission permissionState = P2pPermission.granted;

  /// What the permission dialog answers.
  bool grantOnRequest = true;

  /// When set, creating and joining groups fail with this code.
  String? refuseWith;

  final List<String> calls = [];
  final List<({String deviceId, String name})> starts = [];
  List<String> advertised = const [];
  ({String networkName, String passphrase})? created;
  ({String networkName, String passphrase})? joined;

  final StreamController<P2pPeer> _found = StreamController.broadcast();
  final StreamController<P2pGroup> _groups = StreamController.broadcast();

  void see(P2pPeer peer) => _found.add(peer);
  void group(P2pGroup group) => _groups.add(group);

  @override
  Stream<P2pPeer> get found => _found.stream;

  @override
  Stream<P2pGroup> get groups => _groups.stream;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<P2pPermission> permission() async => permissionState;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    if (grantOnRequest) permissionState = P2pPermission.granted;
    return grantOnRequest;
  }

  @override
  Future<void> openLocationSettings() async => calls.add('location');

  @override
  Future<void> start({required String deviceId, required String name}) async {
    calls.add('start');
    starts.add((deviceId: deviceId, name: name));
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> advertise(List<String> seen) async => advertised = seen;

  @override
  Future<void> createGroup(String networkName, String passphrase) async {
    calls.add('create');
    _refuse();
    created = (networkName: networkName, passphrase: passphrase);
  }

  @override
  Future<void> joinGroup(String networkName, String passphrase) async {
    calls.add('join:$networkName');
    _refuse();
    joined = (networkName: networkName, passphrase: passphrase);
  }

  @override
  Future<void> leaveGroup() async => calls.add('leave');

  void _refuse() {
    final code = refuseWith;
    if (code != null) throw PlatformException(code: code);
  }
}
