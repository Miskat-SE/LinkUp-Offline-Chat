// Encryption spike for PROJECT_PLAN.md P9.5 (D17): plaintext TCP versus
// TLS 1.3 with a self-signed server certificate pinned by SHA-256
// fingerprint (dart:io can't accept an unknown self-signed *client*
// certificate, so only the accepting side is pinned), using the same write pattern as file transfers
// (64 KiB chunks, flush every 1 MiB). Needs `openssl` on PATH.
//
//   dart run tool/tls_spike.dart [megabytes]
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final megabytes = args.isEmpty ? 512 : int.parse(args.first);
  final dir = await Directory.systemTemp.createTemp('tls_spike');
  try {
    final server = await _identity(dir, 'server');
    final client = await _identity(dir, 'client');
    stdout.writeln('Moving $megabytes MB over loopback, 3 runs each:\n');
    for (final tls in [false, true]) {
      final rates = <double>[];
      for (var run = 0; run < 3; run++) {
        rates.add(await _transfer(megabytes, tls ? (server, client) : null));
      }
      rates.sort();
      stdout.writeln(
        '${tls ? 'TLS 1.3 (pinned) ' : 'plaintext        '}'
        'median ${rates[1].toStringAsFixed(0)} MB/s  '
        '(runs: ${rates.map((r) => r.toStringAsFixed(0)).join(', ')})',
      );
    }
    final handshakes = await _handshakes(server, client, 50);
    stdout.writeln(
      '\nTLS handshake with the server pinned: median '
      '${handshakes.toStringAsFixed(1)} ms over 50 connections',
    );
  } finally {
    await dir.delete(recursive: true);
  }
}

/// A self-signed P-256 certificate and its pin (SHA-256 of the DER).
final class _Identity {
  _Identity(this.context, this.pin);

  final SecurityContext context;
  final String pin;
}

Future<_Identity> _identity(Directory dir, String name) async {
  final key = '${dir.path}/$name.key';
  final cert = '${dir.path}/$name.pem';
  final result = await Process.run('openssl', [
    'req',
    '-x509',
    '-newkey',
    'ec',
    '-pkeyopt',
    'ec_paramgen_curve:P-256',
    '-nodes',
    '-keyout',
    key,
    '-out',
    cert,
    '-days',
    '3650',
    '-subj',
    '/CN=$name',
  ]);
  if (result.exitCode != 0) throw StateError('openssl: ${result.stderr}');
  final der = await Process.run('openssl', [
    'x509',
    '-in',
    cert,
    '-outform',
    'DER',
    '-out',
    '$cert.der',
  ]);
  if (der.exitCode != 0) throw StateError('openssl: ${der.stderr}');
  final pin = sha256.convert(await File('$cert.der').readAsBytes()).toString();
  final context = SecurityContext()
    ..useCertificateChain(cert)
    ..usePrivateKey(key);
  return _Identity(context, pin);
}

/// Sends [megabytes] and returns MB/s as seen by the receiver.
Future<double> _transfer(int megabytes, (_Identity, _Identity)? tls) async {
  final total = megabytes << 20;
  final chunk = Uint8List(64 * 1024);
  final received = Completer<Duration>();
  final watch = Stopwatch()..start();
  late final Stream<Socket> incoming;
  late final int port;
  late final Future<void> Function() closeServer;
  if (tls == null) {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    incoming = server;
    port = server.port;
    closeServer = server.close;
  } else {
    final server = await SecureServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
      tls.$1.context,
    );
    incoming = server;
    port = server.port;
    closeServer = server.close;
  }
  incoming.listen((socket) async {
    var got = 0;
    await for (final data in socket) {
      got += data.length;
      if (got >= total) {
        received.complete(watch.elapsed);
        break;
      }
    }
    socket.destroy();
  });

  final Socket socket;
  if (tls == null) {
    socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  } else {
    socket = await SecureSocket.connect(
      InternetAddress.loopbackIPv4,
      port,
      context: tls.$2.context,
      // Self-signed: trust exactly the pinned certificate.
      onBadCertificate: (cert) =>
          sha256.convert(cert.der).toString() == tls.$1.pin,
    );
  }
  var sent = 0;
  var unflushed = 0;
  while (sent < total) {
    socket.add(chunk);
    sent += chunk.length;
    unflushed += chunk.length;
    if (unflushed >= 1 << 20) {
      await socket.flush();
      unflushed = 0;
    }
  }
  await socket.flush();
  final elapsed = await received.future;
  socket.destroy();
  await closeServer();
  return megabytes / (elapsed.inMicroseconds / 1e6);
}

/// Median time to connect and finish a mutually pinned TLS handshake.
Future<double> _handshakes(
  _Identity server,
  _Identity client,
  int count,
) async {
  final listener = await SecureServerSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
    server.context,
  );
  listener.listen((s) => s.destroy());
  final times = <double>[];
  for (var i = 0; i < count; i++) {
    final watch = Stopwatch()..start();
    final socket = await SecureSocket.connect(
      InternetAddress.loopbackIPv4,
      listener.port,
      context: client.context,
      onBadCertificate: (cert) =>
          sha256.convert(cert.der).toString() == server.pin,
    );
    times.add(watch.elapsedMicroseconds / 1000);
    socket.destroy();
  }
  await listener.close();
  times.sort();
  return times[count ~/ 2];
}
