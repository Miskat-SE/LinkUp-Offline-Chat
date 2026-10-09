import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/network/connection/connection_manager.dart';
import 'package:resqmesh/core/network/connection/peer_connection.dart';
import 'package:resqmesh/core/network/connection/peer_links.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/protocol/frame_codec.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

// IDs sort A < B < C, so A dials B first (PROJECT_PLAN.md §5.5 rule 7).
const idA = 'aaaaaaaa-0000-4000-8000-000000000001';
const idB = 'bbbbbbbb-0000-4000-8000-000000000002';
const idC = 'cccccccc-0000-4000-8000-000000000003';

const fast = ConnectionTiming(
  connectTimeout: Duration(seconds: 1),
  helloTimeout: Duration(milliseconds: 500),
  pingInterval: Duration(milliseconds: 100),
  idleTimeout: Duration(milliseconds: 400),
  reconnectBase: Duration(milliseconds: 50),
  reconnectMax: Duration(milliseconds: 200),
  dialGrace: Duration(milliseconds: 300),
);

/// One device with real TCP sockets on loopback.
final class Node {
  Node(
    this.id,
    this.name, {
    ConnectionTiming timing = fast,
    int port = 0,
    this.announce = true,
  }) {
    links = ConnectionManager(
      self: () => SelfInfo(
        deviceId: id,
        name: name,
        nameClaimedAt: DateTime.utc(2026),
        announce: announce,
        appVersion: 'test',
      ),
      logger: AppLogger(),
      preferredPort: port,
      timing: timing,
      bindAddress: InternetAddress.loopbackIPv4,
    );
  }

  final String id;
  final String name;
  bool announce;
  late final ConnectionManager links;
  int port = 0;

  Future<Node> start() async {
    port = (await links.start())!;
    addTearDown(links.stop);
    return this;
  }

  PeerEndpoint get endpoint =>
      PeerEndpoint(deviceId: id, address: '127.0.0.1', port: port);

  LinkInfo? linkTo(Node other) => links.current.links[other.id];
}

/// Polls until [condition] holds, failing after [timeout].
Future<void> eventually(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting${reason == null ? '' : ': $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// A hand-driven client for testing the server's defences.
final class RawClient {
  RawClient._(this.socket) {
    socket.listen(
      (_) {},
      onDone: _markClosed,
      onError: (Object _) => _markClosed(),
    );
    // Writing to a socket the server already reset fails here; that is
    // expected in refusal tests, not an error.
    unawaited(socket.done.then((_) {}, onError: (Object _) {}));
  }

  void _markClosed() {
    if (!_closed.isCompleted) _closed.complete();
  }

  static Future<RawClient> connect(int port) async =>
      RawClient._(await Socket.connect(InternetAddress.loopbackIPv4, port));

  final Socket socket;
  final Completer<void> _closed = Completer();

  Future<void> get closedByServer => _closed.future;

  void sendHello({String id = idC, String name = 'Raw'}) => sendPacket(
    HelloPacket(
      PacketHeader.create(senderId: id, senderName: name),
      Announcement(
        tcpPort: 1,
        appVersion: 'raw',
        nameClaimedAt: DateTime.utc(2026),
      ),
    ),
  );

  void sendPacket(Packet packet) => socket.add(
    FrameCodec.encode(FrameKind.control, PacketCodec.encode(packet)),
  );

  void sendRaw(List<int> bytes) => socket.add(bytes);

  void close() => socket.destroy();
}

void main() {
  test('the lower ID dials and both sides see the connection', () async {
    final a = await Node(idA, 'Yusuf').start();
    final b = await Node(idB, 'Rahim').start();
    a.links.updateEndpoints([b.endpoint]);

    await eventually(() => a.linkTo(b) != null && b.linkTo(a) != null);
    expect(a.linkTo(b)!.direction, ConnectionDirection.outbound);
    expect(b.linkTo(a)!.direction, ConnectionDirection.inbound);
    expect(a.linkTo(b)!.peerName, 'Rahim');
    expect(b.linkTo(a)!.peerName, 'Yusuf');
  });

  test(
    'the higher ID dials after the grace period if nobody else does',
    () async {
      final a = await Node(idA, 'Yusuf').start();
      final b = await Node(idB, 'Rahim').start();
      // Only B discovered A (for example, A's broadcasts were filtered).
      final started = DateTime.now();
      b.links.updateEndpoints([a.endpoint]);

      await eventually(() => b.linkTo(a) != null);
      expect(
        DateTime.now().difference(started),
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
      expect(b.linkTo(a)!.direction, ConnectionDirection.outbound);
    },
  );

  test(
    'when both dial at once, the connection opened by the lower ID wins',
    () async {
      const noGrace = ConnectionTiming(
        helloTimeout: Duration(milliseconds: 500),
        reconnectBase: Duration(milliseconds: 50),
        dialGrace: Duration.zero,
      );
      final a = await Node(idA, 'Yusuf', timing: noGrace).start();
      final b = await Node(idB, 'Rahim', timing: noGrace).start();
      a.links.updateEndpoints([b.endpoint]);
      b.links.updateEndpoints([a.endpoint]);

      await eventually(() => a.linkTo(b) != null && b.linkTo(a) != null);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(a.links.current.links, hasLength(1));
      expect(b.links.current.links, hasLength(1));
      expect(a.linkTo(b)!.direction, ConnectionDirection.outbound);
      expect(b.linkTo(a)!.direction, ConnectionDirection.inbound);
    },
  );

  test('keep-alive measures the round-trip time', () async {
    final a = await Node(idA, 'Yusuf').start();
    final b = await Node(idB, 'Rahim').start();
    a.links.updateEndpoints([b.endpoint]);
    await eventually(() => a.linkTo(b) != null);

    await eventually(() {
      // Snapshots refresh when anything changes; poke it.
      a.links.updateEndpoints([b.endpoint]);
      return a.linkTo(b)?.rttMs != null;
    });
    expect(a.linkTo(b)!.rttMs, lessThan(200));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(a.linkTo(b), isNotNull, reason: 'PONGs keep it alive');
  });

  test('a silent peer is dropped after the idle timeout', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);
    raw.sendHello();
    await eventually(() => a.links.current.links.containsKey(idC));

    // Never answers PING.
    await raw.closedByServer.timeout(const Duration(seconds: 2));
    await eventually(() => !a.links.current.links.containsKey(idC));
  });

  test('a connection that never says HELLO is closed and not kept', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);

    await raw.closedByServer.timeout(const Duration(seconds: 2));
    expect(a.links.current.links, isEmpty);
    await eventually(() => a.links.current.stats.handshakeFailures == 1);
  });

  test('other packets before HELLO are refused', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);
    raw.sendPacket(
      PingPacket(
        PacketHeader.create(senderId: idC, senderName: 'Raw'),
        nonce: 1,
      ),
    );
    await raw.closedByServer.timeout(const Duration(seconds: 2));
    expect(a.links.current.links, isEmpty);
  });

  test('three malformed frames in a row close the connection', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);
    raw.sendHello();
    await eventually(() => a.links.current.links.containsKey(idC));

    for (var i = 0; i < 3; i++) {
      raw.sendRaw(FrameCodec.encode(FrameKind.control, utf8.encode('{nope')));
    }
    await raw.closedByServer.timeout(const Duration(seconds: 2));
  });

  test('an oversized frame header closes the connection at once', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);
    raw.sendHello();
    await eventually(() => a.links.current.links.containsKey(idC));

    final header = ByteData(5)
      ..setUint8(0, 0x01)
      ..setUint32(1, 0x7FFFFFFF);
    raw.sendRaw(header.buffer.asUint8List());
    await raw.closedByServer.timeout(const Duration(seconds: 2));
  });

  test('a connection claiming to be this device is refused', () async {
    final a = await Node(idA, 'Yusuf').start();
    final raw = await RawClient.connect(a.port);
    addTearDown(raw.close);
    raw.sendHello(id: idA);
    await raw.closedByServer.timeout(const Duration(seconds: 2));
    expect(a.links.current.links, isEmpty);
  });

  test('a different device at the address is not trusted', () async {
    final a = await Node(idA, 'Yusuf').start();
    final b = await Node(idB, 'Rahim').start();
    // Discovery thinks C lives at B's address (stale IP).
    a.links.updateEndpoints([
      PeerEndpoint(deviceId: idC, address: '127.0.0.1', port: b.port),
    ]);

    await eventually(() => a.links.current.unreachable.contains(idC));
    expect(a.links.current.links, isEmpty);
  });

  test('a lost connection is redialled when the peer is back', () async {
    final a = await Node(idA, 'Yusuf').start();
    var b = await Node(idB, 'Rahim').start();
    final port = b.port;
    a.links.updateEndpoints([b.endpoint]);
    await eventually(() => a.linkTo(b) != null);

    await b.links.stop();
    await eventually(() => a.linkTo(b) == null, reason: 'loss noticed');

    b = await Node(idB, 'Rahim', port: port).start();
    await eventually(() => a.linkTo(b) != null, reason: 'reconnected');
  });

  test('a network reset drops connections and builds them again', () async {
    final a = await Node(idA, 'Yusuf').start();
    final b = await Node(idB, 'Rahim').start();
    a.links.updateEndpoints([b.endpoint]);
    await eventually(() => a.linkTo(b) != null);

    final newPort = await a.links.resetNetwork();
    expect(newPort, isNotNull);
    expect(a.links.current.links, isEmpty);
    a.links.updateEndpoints([b.endpoint]);
    await eventually(() => a.linkTo(b) != null && b.linkTo(a) != null);
  });

  test('packets other than keep-alive reach the other side', () async {
    final a = await Node(idA, 'Yusuf').start();
    final b = await Node(idB, 'Rahim').start();
    a.links.updateEndpoints([b.endpoint]);
    await eventually(() => a.linkTo(b) != null && b.linkTo(a) != null);

    final received = b.links.packets.first;
    expect(
      a.links.send(
        idB,
        RegisterPacket(
          PacketHeader.create(senderId: idA, senderName: 'Yusuf'),
          name: 'Yusuf',
          nameClaimedAt: DateTime.utc(2026),
        ),
      ),
      isTrue,
    );
    final packet = await received.timeout(const Duration(seconds: 2));
    expect(packet.from, idA);
    expect(packet.packet, isA<RegisterPacket>());
    expect(a.links.send(idC, packet.packet), isFalse, reason: 'not connected');
  });

  test('a device still in onboarding accepts no connections', () async {
    final a = Node(idA, 'Yusuf', announce: false);
    await a.start();
    // The server drops the socket at once, so connecting may itself fail
    // with "connection reset"; either way the connection is refused.
    try {
      final raw = await RawClient.connect(a.port);
      addTearDown(raw.close);
      raw.sendHello();
      await raw.closedByServer.timeout(const Duration(seconds: 2));
    } on SocketException {
      // Refused before the client finished connecting.
    }
    expect(a.links.current.links, isEmpty);
  });

  test('the preferred port falls back to a free one when taken', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);
    final a = Node(idA, 'Yusuf', port: blocker.port);
    await a.start();
    expect(a.port, isNot(blocker.port));
    expect(a.port, greaterThan(0));
  });
}
