import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resqmesh/core/platform/bluetooth.dart';

/// Bluetooth radios in one test: phones on the same [FakeAir] can open
/// links to each other's servers and exchange bytes.
final class FakeAir {
  final Map<(String, int), FakeBluetooth> _servers = {};
  final Map<(FakeBluetooth, int), (FakeBluetooth, int)> _pairs = {};
}

/// A [Bluetooth] the test drives.
final class FakeBluetooth implements Bluetooth {
  FakeBluetooth({this.address = 'AA:AA:AA:AA:AA:01', FakeAir? air})
    : air = air ?? FakeAir();

  final String address;
  final FakeAir air;
  bool supported = true;
  bool enabled = true;
  BtPermission permissionState = BtPermission.granted;
  bool grantOnRequest = true;
  final List<String> calls = [];
  ({String deviceId, int channel})? advertising;

  int _nextChannel = 0x81;
  int _nextLink = 1;

  // Lives as long as the test.
  // ignore: close_sinks
  final StreamController<BtFound> _found = StreamController.broadcast();
  // ignore: close_sinks
  final StreamController<BtLinkEvent> _links = StreamController.broadcast();
  final StreamController<bool> _enabled = StreamController.broadcast();

  void see(BtFound peer) => _found.add(peer);
  void setEnabled(bool on) {
    enabled = on;
    _enabled.add(on);
  }

  @override
  Stream<BtFound> get found => _found.stream;

  @override
  Stream<BtLinkEvent> get links => _links.stream;

  @override
  Stream<bool> get enabledChanges => _enabled.stream;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<BtPermission> permission() async => permissionState;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    if (grantOnRequest) permissionState = BtPermission.granted;
    return grantOnRequest;
  }

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> requestEnable() async => calls.add('enable');

  @override
  Future<void> openLocationSettings() async => calls.add('location');

  @override
  Future<int> openServer() async {
    // Like Android: no server without permission, or with Bluetooth off.
    if (permissionState != BtPermission.granted || !enabled) {
      throw PlatformException(code: 'permission');
    }
    final channel = _nextChannel++;
    air._servers[(address, channel)] = this;
    return channel;
  }

  @override
  Future<void> closeServer(int channel) async {
    air._servers.remove((address, channel));
  }

  @override
  Future<void> startDiscovery(String deviceId, int channel) async {
    calls.add('discover');
    advertising = (deviceId: deviceId, channel: channel);
  }

  @override
  Future<void> stopDiscovery() async {
    calls.add('stopDiscovery');
    advertising = null;
  }

  @override
  Future<int> connect(String address, int channel) async {
    final server = air._servers[(address, channel)];
    if (server == null) {
      throw PlatformException(code: 'unreachable', message: 'Nobody there');
    }
    final mine = _nextLink++;
    final theirs = server._nextLink++;
    air._pairs[(this, mine)] = (server, theirs);
    air._pairs[(server, theirs)] = (this, mine);
    server._links.add(BtLinkOpened(theirs, this.address, channel));
    return mine;
  }

  @override
  void send(int linkId, Uint8List bytes) {
    final other = air._pairs[(this, linkId)];
    if (other == null) return;
    final (phone, id) = other;
    scheduleMicrotask(() => phone._links.add(BtData(id, bytes)));
  }

  @override
  void closeLink(int linkId) {
    final other = air._pairs.remove((this, linkId));
    if (other == null) return;
    air._pairs.remove(other);
    final (phone, id) = other;
    scheduleMicrotask(() => phone._links.add(BtLinkClosed(id)));
  }
}
