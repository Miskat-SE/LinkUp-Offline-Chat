import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:resqmesh/core/network/discovery/datagram_transport.dart';

/// An in-memory LAN for discovery tests. Broadcasts reach every endpoint on
/// the port (the sender included, as on a real network); unicasts reach the
/// endpoint with that address.
final class MemoryDatagramNetwork {
  final List<_Endpoint> _endpoints = [];

  /// Simulates a router that drops broadcast packets.
  bool dropBroadcasts = false;

  /// Addresses whose traffic is lost (a phone that walked away).
  final Set<String> unreachable = {};

  /// A binder for the device with address [ip]. Set [blocked] to fail like
  /// Android does without local network access.
  DatagramBinder binderFor(String ip, {bool blocked = false}) => (port) async {
    if (blocked) {
      throw const SocketException(
        'Operation not permitted',
        osError: OSError('Operation not permitted', 1),
      );
    }
    final endpoint = _Endpoint(this, ip, port);
    _endpoints.add(endpoint);
    return endpoint;
  };

  void _deliver(_Endpoint from, Uint8List data, String to, int port) {
    if (unreachable.contains(from.ip)) return;
    final broadcast = to == '255.255.255.255' || to.endsWith('.255');
    if (broadcast && dropBroadcasts) return;
    for (final endpoint in List.of(_endpoints)) {
      if (endpoint.closed || endpoint.port != port) continue;
      if (unreachable.contains(endpoint.ip)) continue;
      if (broadcast || endpoint.ip == to) {
        endpoint._incoming.add(
          ReceivedDatagram(Uint8List.fromList(data), from.ip, from.port),
        );
      }
    }
  }

  /// The socket of the device at [ip] fails, as when Android cuts a
  /// backgrounded app's network: an error, then nothing more arrives.
  void breakSocket(String ip) {
    for (final endpoint in _endpoints) {
      if (endpoint.ip != ip || endpoint.closed) continue;
      endpoint._incoming.addError(
        const SocketException('Software caused connection abort'),
      );
      endpoint.closed = true;
    }
  }

  /// Delivers raw bytes as if sent by [fromIp].
  void inject(Uint8List data, {required String fromIp, required int toPort}) {
    for (final endpoint in _endpoints) {
      if (!endpoint.closed && endpoint.port == toPort) {
        endpoint._incoming.add(ReceivedDatagram(data, fromIp, toPort));
      }
    }
  }
}

final class _Endpoint implements DatagramTransport {
  _Endpoint(this._network, this.ip, this.port);

  final MemoryDatagramNetwork _network;
  final String ip;
  final int port;
  bool closed = false;
  final StreamController<ReceivedDatagram> _incoming =
      StreamController<ReceivedDatagram>.broadcast();

  @override
  Stream<ReceivedDatagram> get incoming => _incoming.stream;

  @override
  void send(Uint8List data, String address, int port) {
    if (closed) throw const SocketException('closed');
    _network._deliver(this, data, address, port);
  }

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }
}
