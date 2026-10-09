import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

final class ReceivedDatagram {
  const ReceivedDatagram(this.data, this.address, this.port);

  final Uint8List data;

  /// Sender's IPv4 address.
  final String address;
  final int port;
}

/// Sends and receives UDP datagrams. Lets the discovery engine run over real
/// sockets on phones and over an in-memory network in tests.
abstract interface class DatagramTransport {
  Stream<ReceivedDatagram> get incoming;

  /// Throws [SocketException] if the system refuses (for example `EPERM`
  /// when local network access is blocked).
  void send(Uint8List data, String address, int port);

  Future<void> close();
}

typedef DatagramBinder = Future<DatagramTransport> Function(int port);

/// Binds a broadcast-enabled UDP socket on every interface.
Future<DatagramTransport> bindUdp(int port) async => UdpDatagramTransport._(
  // reuseAddress (the default) lets a restarted engine rebind at once.
  await RawDatagramSocket.bind(InternetAddress.anyIPv4, port),
);

final class UdpDatagramTransport implements DatagramTransport {
  UdpDatagramTransport._(this._socket) {
    _socket.broadcastEnabled = true;
    _subscription = _socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? datagram;
      while ((datagram = _socket.receive()) != null) {
        _incoming.add(
          ReceivedDatagram(
            datagram!.data,
            datagram.address.address,
            datagram.port,
          ),
        );
      }
    }, onError: _incoming.addError);
  }

  final RawDatagramSocket _socket;
  final StreamController<ReceivedDatagram> _incoming =
      StreamController<ReceivedDatagram>.broadcast();
  late final StreamSubscription<RawSocketEvent> _subscription;

  /// The local port actually bound.
  int get port => _socket.port;

  @override
  Stream<ReceivedDatagram> get incoming => _incoming.stream;

  @override
  void send(Uint8List data, String address, int port) {
    _socket.send(data, InternetAddress(address), port);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _socket.close();
    await _incoming.close();
  }
}
