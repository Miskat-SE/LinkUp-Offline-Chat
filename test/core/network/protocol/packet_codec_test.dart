import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/protocol/datagram.dart';
import 'package:resqmesh/core/network/protocol/frame_codec.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

const _id = '3f2a9c4e-1b7d-4c55-8e0a-6d2f9b1c7a33';
const _other = 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61';

Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/protocol/$name.json').readAsStringSync())
        as Map<String, Object?>;

Packet decodedPacket(Object? json) => switch (PacketCodec.fromJson(json)) {
  Decoded(:final packet) => packet,
  final other => fail('expected a packet, got $other'),
};

String? malformedReason(Object? json) => switch (PacketCodec.fromJson(json)) {
  Malformed(:final reason) => reason,
  _ => null,
};

PacketHeader header({String name = 'Yusuf', String receiver = '*'}) =>
    PacketHeader(
      messageId: '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10',
      senderId: _id,
      senderName: name,
      receiverId: receiver,
      timestamp: DateTime.utc(2026, 10, 8, 20, 42, 13, 512),
    );

final _announcement = Announcement(
  tcpPort: 28761,
  appVersion: '1.0.0+3',
  nameClaimedAt: DateTime.utc(2026, 10, 8, 19, 2, 44, 120),
);

void main() {
  group('fixtures from PROTOCOL.md', () {
    for (final name in [
      'hello',
      'discovery',
      'name_check',
      'register_response',
      'goodbye',
    ]) {
      test('$name decodes and encodes back to the same JSON', () {
        final json = fixture(name);
        final packet = decodedPacket(json);
        expect(PacketCodec.toJson(packet), json);
      });
    }

    test('HELLO fields are typed', () {
      final hello = decodedPacket(fixture('hello')) as HelloPacket;
      expect(hello.header.senderName, 'Yusuf');
      expect(hello.announcement.tcpPort, 28761);
      expect(
        hello.announcement.nameClaimedAt,
        DateTime.utc(2026, 10, 8, 19, 2, 44, 120),
      );
      expect(hello.announcement.compatible, isTrue);
    });
  });

  group('round trip', () {
    final packets = <Packet>[
      DiscoveryPacket(header(name: '')),
      DiscoveryResponsePacket(header(receiver: _other), _announcement),
      HelloPacket(header(), _announcement),
      GoodbyePacket(header(), reason: 'networkLost'),
      NameCheckPacket(header(name: ''), candidateName: 'Rahim'),
      RegisterPacket(
        header(),
        name: 'Yusuf',
        nameClaimedAt: DateTime.utc(2026, 10, 8),
      ),
      RegisterResponsePacket(
        header(),
        result: RegisterResult.ok,
        name: 'Yusuf',
      ),
    ];
    for (final packet in packets) {
      test(packet.type, () {
        final again = decodedPacket(
          jsonDecode(utf8.decode(PacketCodec.encode(packet))),
        );
        expect(again.runtimeType, packet.runtimeType);
        expect(again.header, packet.header);
        expect(PacketCodec.toJson(again), PacketCodec.toJson(packet));
      });
    }

    test('timestamps are written with millisecond precision', () {
      final created = PacketHeader.create(senderId: _id, senderName: 'Yusuf');
      expect(created.timestamp.microsecond, 0);
      expect(created.timestamp.isUtc, isTrue);
    });
  });

  group('validation', () {
    Map<String, Object?> hello() => fixture('hello');

    test('rejects a wrong protocol version', () {
      final json = hello()..['protocolVersion'] = 2;
      expect(PacketCodec.fromJson(json), isA<UnsupportedVersion>());
    });

    test('ignores unknown packet types', () {
      final json = hello()..['type'] = 'FUTURE_THING';
      expect(PacketCodec.fromJson(json), isA<UnknownType>());
    });

    test('rejects IDs that are not UUIDs', () {
      expect(
        malformedReason(hello()..['senderId'] = '../../etc'),
        contains('senderId'),
      );
      expect(
        malformedReason(hello()..['messageId'] = 42),
        contains('messageId'),
      );
      expect(
        malformedReason(hello()..['receiverId'] = 'everyone'),
        contains('receiverId'),
      );
    });

    test('rejects names that break the username rules', () {
      expect(
        malformedReason(hello()..['senderName'] = 'Y'),
        contains('senderName'),
      );
      expect(
        malformedReason(hello()..['senderName'] = 'Yu\nsuf'),
        contains('senderName'),
      );
      expect(
        malformedReason(hello()..['senderName'] = ' Yusuf'),
        contains('senderName'),
      );
      expect(
        malformedReason(hello()..['senderName'] = ''),
        contains('senderName'),
      );
    });

    test('allows an empty name only before a device has one', () {
      expect(decodedPacket(fixture('discovery')), isA<DiscoveryPacket>());
      expect(decodedPacket(fixture('name_check')), isA<NameCheckPacket>());
    });

    test('rejects missing and wrongly typed payload fields', () {
      Map<String, Object?> withPayload(
        void Function(Map<String, Object?>) edit,
      ) {
        final json = hello();
        edit(json['payload']! as Map<String, Object?>);
        return json;
      }

      expect(
        malformedReason(withPayload((p) => p.remove('tcpPort'))),
        contains('tcpPort'),
      );
      expect(
        malformedReason(withPayload((p) => p['tcpPort'] = 70000)),
        contains('tcpPort'),
      );
      expect(
        malformedReason(withPayload((p) => p['tcpPort'] = '28761')),
        contains('tcpPort'),
      );
      expect(
        malformedReason(withPayload((p) => p['nameClaimedAt'] = 'yesterday')),
        contains('nameClaimedAt'),
      );
      expect(
        malformedReason(withPayload((p) => p['minProtocol'] = 3)),
        contains('minProtocol'),
      );
      expect(
        malformedReason(withPayload((p) => p['capabilities'] = [1])),
        contains('capabilities'),
      );
      expect(malformedReason(hello()..['payload'] = 'x'), contains('payload'));
    });

    test('nameTaken must say who holds the name', () {
      final json = fixture('register_response');
      (json['payload']! as Map<String, Object?>).remove('holderId');
      expect(malformedReason(json), contains('holderId'));
    });

    test('ignores extra payload fields from newer versions', () {
      final json = hello();
      (json['payload']! as Map<String, Object?>)['futureField'] = true;
      expect(decodedPacket(json), isA<HelloPacket>());
    });

    test('never throws on garbage bytes', () {
      for (final bytes in [
        <int>[],
        [0xFF, 0xFE, 0xFD],
        utf8.encode('null'),
        utf8.encode('[1,2,3]'),
        utf8.encode('{"protocolVersion":1}'),
        utf8.encode('{"protocolVersion":1,"type":"HELLO"}'),
      ]) {
        expect(PacketCodec.decode(bytes), isNot(isA<Decoded>()));
      }
    });

    test('rejects control packets over the size limit', () {
      expect(PacketCodec.decode(Uint8List(70 * 1024)), isA<TooLarge>());
    });
  });

  group('UDP datagrams', () {
    test('carry the RQM1 magic and decode back', () {
      final data = DatagramCodec.encode(HelloPacket(header(), _announcement));
      expect(String.fromCharCodes(data.sublist(0, 4)), 'RQM1');
      expect(DatagramCodec.decode(data), isA<Decoded>());
    });

    test("other apps' datagrams are recognised as foreign", () {
      expect(
        DatagramCodec.decode(
          Uint8List.fromList(utf8.encode('M-SEARCH * HTTP/1.1')),
        ),
        isA<Foreign>(),
      );
      expect(DatagramCodec.decode(Uint8List(2)), isA<Foreign>());
    });

    test('oversized datagrams are rejected', () {
      final big = Uint8List(1500)..setRange(0, 4, 'RQM1'.codeUnits);
      expect(DatagramCodec.decode(big), isA<TooLarge>());
    });

    test('a HELLO with the longest name fits in one datagram', () {
      final longName = 'ব' * 30;
      final data = DatagramCodec.encode(
        HelloPacket(header(name: longName), _announcement),
      );
      expect(data.length, lessThan(1400));
    });
  });

  group('TCP frames', () {
    test('split and merged reads give back the same frames', () {
      final one = FrameCodec.encode(FrameKind.control, utf8.encode('{"a":1}'));
      final two = FrameCodec.encode(FrameKind.fileChunk, List.filled(1000, 7));
      final stream = [...one, ...two];
      final decoder = FrameDecoder();
      final frames = <Frame>[];
      // Feed one byte at a time, the worst case for reassembly.
      for (final byte in stream) {
        frames.addAll(decoder.add([byte]));
      }
      expect(frames, hasLength(2));
      expect(frames[0].kind, FrameKind.control);
      expect(utf8.decode(frames[0].body), '{"a":1}');
      expect(frames[1].kind, FrameKind.fileChunk);
      expect(frames[1].body, hasLength(1000));
      expect(decoder.bufferedBytes, 0);

      final together = FrameDecoder().add(stream);
      expect(together, hasLength(2));
    });

    test('rejects an unknown kind before reading the body', () {
      expect(
        () => FrameDecoder().add([0x09, 0, 0, 0, 1]),
        throwsA(isA<FrameException>()),
      );
    });

    test('rejects a control frame over 64 KiB from its header alone', () {
      final header = ByteData(5)
        ..setUint8(0, 0x01)
        ..setUint32(1, 64 * 1024 + 1);
      expect(
        () => FrameDecoder().add(header.buffer.asUint8List()),
        throwsA(isA<FrameException>()),
      );
    });

    test('rejects empty frames', () {
      expect(
        () => FrameDecoder().add([0x01, 0, 0, 0, 0]),
        throwsA(isA<FrameException>()),
      );
    });
  });
}
