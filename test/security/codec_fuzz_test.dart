import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/network/protocol/datagram.dart';
import 'package:resqmesh/core/network/protocol/frame_codec.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

/// P9.2: untrusted bytes never crash the decoders; they are refused.
void main() {
  final random = Random(2026);
  Uint8List bytes(int n) =>
      Uint8List.fromList(List.generate(n, (_) => random.nextInt(256)));

  final valid = PacketCodec.encode(
    MessagePacket(
      PacketHeader.create(
        senderId: '3f2a9c4e-1b7d-4c55-8e0a-6d2f9b1c7a33',
        senderName: 'Yusuf',
        receiverId: 'b81d07aa-5c3e-4f19-9d26-0e7c4a8b2f61',
      ),
      kind: MessageKind.file,
      audience: MessageAudience.direct,
      file: const FileRef(
        fileId: '0a4e6c1d-2b8f-4e57-a3c9-5d1f7e2b9c80',
        name: 'a.zip',
        size: 10,
        mimeType: 'application/zip',
        sha256:
            '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      ),
    ),
  );

  test('random bytes', () {
    for (var i = 0; i < 3000; i++) {
      final data = bytes(random.nextInt(2000));
      expect(PacketCodec.decode(data), isNot(isA<Decoded>()));
      expect(() => DatagramCodec.decode(data), returnsNormally);
    }
  });

  test('truncated and bit-flipped valid packets', () {
    for (var cut = 0; cut < valid.length; cut++) {
      expect(() => PacketCodec.decode(valid.sublist(0, cut)), returnsNormally);
    }
    for (var i = 0; i < 3000; i++) {
      final mutated = Uint8List.fromList(valid);
      for (var j = 0; j < 1 + random.nextInt(4); j++) {
        mutated[random.nextInt(mutated.length)] = random.nextInt(256);
      }
      expect(() => PacketCodec.decode(mutated), returnsNormally);
    }
  });

  test('wrong JSON types in every field', () {
    final json = jsonDecode(utf8.decode(valid)) as Map<String, Object?>;
    final junk = <Object?>[
      null,
      0,
      -1,
      1.5,
      1e308,
      '',
      'x' * 70000,
      true,
      <Object?>[],
      <String, Object?>{},
      [1, 2],
      {'a': 1},
    ];
    void poke(Map<String, Object?> target) {
      for (final key in target.keys.toList()) {
        final original = target[key];
        for (final value in junk) {
          target[key] = value;
          expect(
            () => PacketCodec.fromJson(json),
            returnsNormally,
            reason: key,
          );
        }
        target[key] = original;
        if (original is Map<String, Object?>) poke(original);
      }
    }

    poke(json);
  });

  test('deeply nested JSON within the frame limit', () {
    final depth = ProtocolLimits.nesting;
    final nested = utf8.encode('${'[' * depth}${']' * depth}');
    expect(nested.length, lessThanOrEqualTo(64 * 1024));
    expect(PacketCodec.decode(nested), isNot(isA<Decoded>()));
    final objects = utf8.encode('${'{"a":' * 10000}1${'}' * 10000}');
    expect(PacketCodec.decode(objects), isNot(isA<Decoded>()));
  });

  test('frame decoder: random streams never allocate past the limits', () {
    for (var i = 0; i < 2000; i++) {
      final decoder = FrameDecoder();
      try {
        for (var j = 0; j < 5; j++) {
          decoder.add(bytes(random.nextInt(4096)));
          expect(decoder.bufferedBytes, lessThan(256 * 1024 + 5));
        }
      } on FrameException {
        // Refused: the connection would be closed.
      }
    }
  });
}

/// Limits the fuzz test pushes against.
abstract final class ProtocolLimits {
  static const nesting = 32000;
}
