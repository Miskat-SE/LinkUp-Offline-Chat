import 'dart:typed_data';

import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';
import 'package:resqmesh/core/network/protocol/packet_codec.dart';

/// UDP datagram format: the `RQM1` magic, then the JSON packet
/// (PROTOCOL.md §2.2).
abstract final class DatagramCodec {
  static const _magic = ProtocolConstants.datagramMagic;

  /// Throws [StateError] if the packet doesn't fit in one datagram, which
  /// would be a programming error: discovery packets are small.
  static Uint8List encode(Packet packet) {
    final body = PacketCodec.encode(packet);
    final total = _magic.length + body.length;
    if (total > ProtocolConstants.maxDatagramBytes) {
      throw StateError('${packet.type} is $total bytes, over the UDP limit');
    }
    return Uint8List(total)
      ..setRange(0, _magic.length, _magic)
      ..setRange(_magic.length, total, body);
  }

  static DecodeResult decode(Uint8List datagram) {
    if (datagram.length < _magic.length) return const Foreign();
    for (var i = 0; i < _magic.length; i++) {
      if (datagram[i] != _magic[i]) return const Foreign();
    }
    if (datagram.length > ProtocolConstants.maxDatagramBytes) {
      return TooLarge(datagram.length);
    }
    return PacketCodec.decode(
      Uint8List.sublistView(datagram, _magic.length),
      maxBytes: ProtocolConstants.maxDatagramBytes,
    );
  }
}
