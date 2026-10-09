import 'dart:typed_data';

import 'package:resqmesh/core/constants/protocol_constants.dart';

/// TCP frame kinds (PROTOCOL.md §2.1).
enum FrameKind {
  control(0x01, ProtocolConstants.maxControlFrameBytes),
  fileChunk(0x02, ProtocolConstants.maxFileChunkBytes);

  const FrameKind(this.code, this.maxBytes);

  final int code;
  final int maxBytes;

  static FrameKind? fromCode(int code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}

final class Frame {
  const Frame(this.kind, this.body);

  final FrameKind kind;
  final Uint8List body;
}

/// The peer broke the framing rules; the connection must be closed.
final class FrameException implements Exception {
  const FrameException(this.message);

  final String message;

  @override
  String toString() => 'FrameException: $message';
}

abstract final class FrameCodec {
  static const headerBytes = 5;

  static Uint8List encode(FrameKind kind, List<int> body) {
    if (body.isEmpty || body.length > kind.maxBytes) {
      throw ArgumentError.value(body.length, 'body', 'size not allowed');
    }
    final frame = Uint8List(headerBytes + body.length);
    ByteData.sublistView(frame)
      ..setUint8(0, kind.code)
      ..setUint32(1, body.length);
    frame.setRange(headerBytes, frame.length, body);
    return frame;
  }
}

/// Turns a TCP byte stream back into frames. Checks the kind and length of
/// each frame before buffering its body, so a hostile length can't make it
/// allocate memory.
final class FrameDecoder {
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);

  /// Adds received bytes and returns every frame they complete. Throws
  /// [FrameException] if the stream breaks the rules.
  List<Frame> add(List<int> chunk) {
    _buffer
      ..add(_pending)
      ..add(chunk);
    var data = _buffer.takeBytes();
    final frames = <Frame>[];
    while (data.length >= FrameCodec.headerBytes) {
      final header = ByteData.sublistView(data, 0, FrameCodec.headerBytes);
      final kind = FrameKind.fromCode(header.getUint8(0));
      if (kind == null) {
        throw FrameException('unknown frame kind ${header.getUint8(0)}');
      }
      final length = header.getUint32(1);
      if (length == 0 || length > kind.maxBytes) {
        throw FrameException('${kind.name} frame of $length bytes');
      }
      final end = FrameCodec.headerBytes + length;
      if (data.length < end) break;
      frames.add(
        Frame(
          kind,
          Uint8List.fromList(data.sublist(FrameCodec.headerBytes, end)),
        ),
      );
      data = Uint8List.sublistView(data, end);
    }
    _pending = Uint8List.fromList(data);
    return frames;
  }

  /// Bytes received but not yet part of a whole frame.
  int get bufferedBytes => _pending.length;
}
