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
const _fileId = '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80';
const _sha = '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08';

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
      'file_offer',
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
      PingPacket(header(receiver: _other), nonce: 42),
      MessagePacket(
        header(receiver: _other),
        kind: MessageKind.text,
        audience: MessageAudience.direct,
        text: 'Are you coming? 👋',
        replyToId: '9c8b7a65-4321-4fed-8cba-0987654321ab',
      ),
      MessagePacket(
        header(receiver: _other),
        kind: MessageKind.file,
        audience: MessageAudience.broadcast,
        file: const FileRef(
          fileId: '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80',
          name: 'project.zip',
          size: 25794560,
          mimeType: 'application/zip',
          sha256: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
        ),
      ),
      MessageAckPacket(header(receiver: _other), ackFor: _id),
      MessageDeliveredPacket(header(receiver: _other), messageIds: const [_id]),
      MessageReadPacket(
        header(receiver: _other),
        messageIds: const [_id, _other],
      ),
      PongPacket(header(receiver: _other), nonce: 42),
      RegisterResponsePacket(
        header(),
        result: RegisterResult.ok,
        name: 'Yusuf',
      ),
      HelloPacket(
        header(),
        Announcement(
          tcpPort: 28761,
          filePort: 28762,
          appVersion: '1.0.0+8',
          nameClaimedAt: DateTime.utc(2026, 10, 8),
        ),
      ),
      FileOfferPacket(
        header(receiver: _other),
        fileId: _fileId,
        chatMessageId: _id,
        fileName: 'ছবি 01.jpg',
        fileSize: 0,
        mimeType: 'image/jpeg',
        sha256: _sha,
      ),
      FileAcceptPacket(header(receiver: _other), fileId: _fileId, offset: 4096),
      for (final reason in FileRejectReason.values)
        FileRejectPacket(
          header(receiver: _other),
          fileId: _fileId,
          reason: reason,
        ),
      FileCompletePacket(
        header(receiver: _other),
        fileId: _fileId,
        sha256: _sha,
      ),
      for (final reason in FileCancelReason.values)
        FileCancelPacket(
          header(receiver: _other),
          fileId: _fileId,
          reason: reason,
        ),
    ];
    for (final packet in packets) {
      test('${packet.type} ${PacketCodec.toJson(packet)['payload']}', () {
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
    Map<String, Object?> offer() => fixture('file_offer');
    Map<String, Object?> payloadOf(Map<String, Object?> json) =>
        json['payload']! as Map<String, Object?>;

    test('HELLO without a file port is from a device that cannot receive '
        'files', () {
      final packet = decodedPacket(hello()) as HelloPacket;
      expect(packet.announcement.filePort, isNull);
      final json = hello();
      payloadOf(json)['filePort'] = 70000;
      expect(malformedReason(json), contains('filePort'));
    });

    test('FILE_OFFER fields are checked', () {
      final offerPacket = decodedPacket(offer()) as FileOfferPacket;
      expect(offerPacket.fileSize, 25794560);
      expect(offerPacket.chatMessageId, '6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10');

      String? broken(String key, Object? value) {
        final json = offer();
        payloadOf(json)[key] = value;
        return malformedReason(json);
      }

      expect(broken('fileId', '../x'), contains('fileId'));
      expect(broken('fileSize', -1), contains('fileSize'));
      expect(broken('fileSize', 1.5), contains('fileSize'));
      expect(broken('sha256', 'ABC'), contains('sha256'));
      expect(broken('sha256', _sha.toUpperCase()), contains('sha256'));
      expect(broken('fileName', ''), contains('name'));
      // 100 Bangla letters are 300 UTF-8 bytes: over the 255-byte limit.
      expect(broken('fileName', 'ক' * 100), contains('name'));
      expect(broken('mimeType', 'x' * 128), contains('mimeType'));
    });

    test('unknown reject and cancel reasons are refused', () {
      final json = offer()
        ..['type'] = 'FILE_CANCEL'
        ..['payload'] = {'fileId': _fileId, 'reason': 'bored'};
      expect(malformedReason(json), contains('reason'));
      json['type'] = 'FILE_REJECT';
      expect(malformedReason(json), contains('reason'));
    });

    test('FILE_ACCEPT offsets cannot be negative', () {
      final json = offer()
        ..['type'] = 'FILE_ACCEPT'
        ..['payload'] = {'fileId': _fileId, 'offset': -5};
      expect(malformedReason(json), contains('offset'));
    });

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

    test('chat messages are validated', () {
      Map<String, Object?> message(Map<String, Object?> payload) =>
          PacketCodec.toJson(
            MessagePacket(
              header(receiver: _other),
              kind: MessageKind.text,
              audience: MessageAudience.direct,
              text: 'x',
            ),
          )..['payload'] = payload;

      expect(
        malformedReason(message({'messageType': 'text', 'audience': 'direct'})),
        contains('text'),
      );
      expect(
        malformedReason(
          message({'messageType': 'text', 'audience': 'direct', 'text': '   '}),
        ),
        contains('text'),
      );
      expect(
        malformedReason(
          message({
            'messageType': 'text',
            'audience': 'direct',
            'text': 'a' * (16 * 1024 + 1),
          }),
        ),
        contains('text'),
      );
      expect(
        malformedReason(
          message({'messageType': 'text', 'audience': 'everyone', 'text': 'x'}),
        ),
        contains('audience'),
      );
      expect(
        malformedReason(
          message({
            'messageType': 'text',
            'audience': 'direct',
            'text': 'x',
            'replyToId': 'nope',
          }),
        ),
        contains('replyToId'),
      );
      expect(
        malformedReason(
          message({
            'messageType': 'file',
            'audience': 'direct',
            'file': {
              'fileId': _id,
              'name': 'a.zip',
              'size': 1,
              'mimeType': 'application/zip',
              'sha256': 'not-a-hash',
            },
          }),
        ),
        contains('sha256'),
      );
    });

    test('receipts carry 1 to 100 message IDs', () {
      Map<String, Object?> read(List<Object?> ids) => PacketCodec.toJson(
        MessageReadPacket(header(receiver: _other), messageIds: const [_id]),
      )..['payload'] = {'messageIds': ids};
      expect(malformedReason(read([])), contains('empty'));
      expect(
        malformedReason(read(List.filled(101, _id))),
        contains('too long'),
      );
      expect(malformedReason(read(['x'])), contains('IDs'));
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

  test('MESSAGE_DELETE round-trips and needs IDs (P15.4)', () {
    final header = PacketHeader.create(
      senderId: 'aaaaaaaa-0000-4000-8000-000000000001',
      senderName: 'Yusuf',
      receiverId: 'bbbbbbbb-0000-4000-8000-000000000002',
    );
    final packet = MessageDeletePacket(
      header,
      messageIds: const ['6f1c2a0e-8a4b-4d1e-9a51-2c7f0b3e9d10'],
    );
    final decoded = PacketCodec.decode(PacketCodec.encode(packet));
    expect(
      ((decoded as Decoded).packet as MessageDeletePacket).messageIds,
      packet.messageIds,
    );
    final empty = MessageDeletePacket(header, messageIds: const []);
    expect(PacketCodec.decode(PacketCodec.encode(empty)), isA<Malformed>());
  });

  test('MESSAGE mentions are optional IDs (P15.5)', () {
    final header = PacketHeader.create(
      senderId: 'aaaaaaaa-0000-4000-8000-000000000001',
      senderName: 'Yusuf',
      receiverId: 'bbbbbbbb-0000-4000-8000-000000000002',
    );
    MessagePacket roundTrip(MessagePacket packet) =>
        (PacketCodec.decode(PacketCodec.encode(packet)) as Decoded).packet
            as MessagePacket;
    const rahim = 'bbbbbbbb-0000-4000-8000-000000000002';
    final withMention = MessagePacket(
      header,
      kind: MessageKind.text,
      audience: MessageAudience.broadcast,
      text: 'Hi @Rahim',
      mentions: const [rahim],
    );
    expect(roundTrip(withMention).mentions, [rahim]);
    final plain = MessagePacket(
      header,
      kind: MessageKind.text,
      audience: MessageAudience.broadcast,
      text: 'Hi all',
    );
    expect(utf8.decode(PacketCodec.encode(plain)), isNot(contains('mentions')));
    expect(roundTrip(plain).mentions, isEmpty);
    final bad = MessagePacket(
      header,
      kind: MessageKind.text,
      audience: MessageAudience.broadcast,
      text: 'Hi',
      mentions: const ['not-an-id'],
    );
    expect(PacketCodec.decode(PacketCodec.encode(bad)), isA<Malformed>());
  });
}
