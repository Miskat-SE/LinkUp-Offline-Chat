import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// A two-way byte stream to one device: a TCP socket on Wi-Fi, or a
/// Bluetooth channel (P14). Connections, framing and the HELLO handshake
/// work the same over either.
abstract interface class ByteLink {
  /// The other side's address: an IP, or a Bluetooth address.
  String get address;

  /// Bytes as they arrive; done when the other side closes. One listener.
  Stream<Uint8List> get input;

  void add(List<int> bytes);

  /// Closes at once, dropping anything not yet sent.
  void destroy();
}

/// Accepts and opens [ByteLink]s: TCP, or Bluetooth.
abstract interface class LinkTransport {
  /// Starts accepting links, handed to [onLink]; returns what others use to
  /// reach this phone (a TCP port, or a Bluetooth channel), or null.
  Future<int?> listen(void Function(ByteLink link) onLink);

  /// Stops accepting; open links stay open.
  Future<void> close();

  /// Opens a link. Throws [LinkException] (or [SocketException]) when the
  /// other side can't be reached.
  Future<ByteLink> connect(String address, int port, Duration timeout);
}

/// A link that couldn't be opened.
final class LinkException implements Exception {
  const LinkException(this.message);

  final String message;

  @override
  String toString() => 'LinkException: $message';
}

/// A TCP socket as a [ByteLink].
final class SocketLink implements ByteLink {
  SocketLink(this._socket) {
    // Errors from writing to a dead socket surface here, not at add().
    unawaited(_socket.done.catchError((Object _) {}));
  }

  final Socket _socket;

  @override
  String get address => _socket.remoteAddress.address;

  @override
  Stream<Uint8List> get input => _socket;

  @override
  void add(List<int> bytes) => _socket.add(bytes);

  @override
  void destroy() => _socket.destroy();
}

/// Opens a TCP connection; replaceable in tests.
typedef SocketConnector = Future<Socket> Function(
  String address,
  int port,
  Duration timeout,
);

Future<Socket> connectSocket(String address, int port, Duration timeout) =>
    Socket.connect(address, port, timeout: timeout);

/// TCP: listens on [preferredPort], or any free port if it is taken.
final class TcpTransport implements LinkTransport {
  TcpTransport({
    this.preferredPort = 0,
    InternetAddress? bindAddress,
    this.connector = connectSocket,
    this.onBindError,
  }) : bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final int preferredPort;
  final InternetAddress bindAddress;
  final SocketConnector connector;
  final void Function(String message)? onBindError;

  ServerSocket? _server;
  StreamSubscription<Socket>? _subscription;

  @override
  Future<int?> listen(void Function(ByteLink link) onLink) async {
    await close();
    for (final port in {preferredPort, 0}) {
      try {
        _server = await ServerSocket.bind(bindAddress, port);
        break;
      } on SocketException catch (e) {
        onBindError?.call(
          'TCP bind $port failed: ${e.osError?.message ?? e.message}',
        );
      }
    }
    final server = _server;
    if (server == null) return null;
    _subscription = server.listen((socket) => onLink(SocketLink(socket)));
    return server.port;
  }

  @override
  Future<void> close() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _server?.close();
    _server = null;
  }

  @override
  Future<ByteLink> connect(String address, int port, Duration timeout) async =>
      SocketLink(await connector(address, port, timeout));
}
