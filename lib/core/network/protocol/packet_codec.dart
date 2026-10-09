import 'dart:convert';
import 'dart:typed_data';

import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/network/protocol/packet.dart';

/// Outcome of decoding untrusted bytes. The codec never throws.
sealed class DecodeResult {
  const DecodeResult();
}

final class Decoded extends DecodeResult {
  const Decoded(this.packet);

  final Packet packet;
}

/// Broken JSON, a missing field, a wrong type or a value out of range.
final class Malformed extends DecodeResult {
  const Malformed(this.reason);

  final String reason;
}

final class UnsupportedVersion extends DecodeResult {
  const UnsupportedVersion(this.version);

  final Object? version;
}

/// A type this build doesn't know; ignored for forward compatibility.
final class UnknownType extends DecodeResult {
  const UnknownType(this.type);

  final String type;
}

final class TooLarge extends DecodeResult {
  const TooLarge(this.bytes);

  final int bytes;
}

/// A UDP datagram without the ResQMesh magic: someone else's traffic.
final class Foreign extends DecodeResult {
  const Foreign();
}

/// JSON encoding and strict validation of control packets (PROTOCOL.md §3–§5).
abstract final class PacketCodec {
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isId(String value) => _uuid.hasMatch(value);

  // Types that may be sent before the device has a name.
  static const _namelessTypes = {PacketType.discovery, PacketType.nameCheck};

  static Uint8List encode(Packet packet) =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson(packet))));

  static Map<String, Object?> toJson(Packet packet) {
    final header = packet.header;
    return {
      'protocolVersion': packet.protocolVersion,
      'type': packet.type,
      'messageId': header.messageId,
      'senderId': header.senderId,
      'senderName': header.senderName,
      'receiverId': header.receiverId,
      'timestamp': _time(header.timestamp),
      'payload': _payload(packet),
    };
  }

  static DecodeResult decode(List<int> bytes, {int? maxBytes}) {
    final limit = maxBytes ?? ProtocolConstants.maxControlFrameBytes;
    if (bytes.length > limit) return TooLarge(bytes.length);
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      return Malformed('not UTF-8 JSON: ${e.message}');
    }
    return fromJson(json);
  }

  static DecodeResult fromJson(Object? json) {
    try {
      if (json is! Map<String, Object?>) {
        throw const _Invalid('not a JSON object');
      }
      final r = _Reader(json);
      final version = json['protocolVersion'];
      if (version != ProtocolConstants.version) {
        return UnsupportedVersion(version);
      }
      final type = r.string('type', maxLength: 64);
      if (!_known.contains(type)) return UnknownType(type);

      final senderName = r.string('senderName', maxLength: 128);
      if (!(senderName.isEmpty && _namelessTypes.contains(type))) {
        _requireName(senderName, 'senderName');
      }
      final receiverId = r.string('receiverId', maxLength: 36);
      if (receiverId != PacketHeader.everyone && !isId(receiverId)) {
        throw const _Invalid('receiverId is not an ID or "*"');
      }
      final header = PacketHeader(
        messageId: r.id('messageId'),
        senderId: r.id('senderId'),
        senderName: senderName,
        receiverId: receiverId,
        timestamp: r.time('timestamp'),
      );
      final p = _Reader(r.map('payload'), prefix: 'payload.');
      return Decoded(_packet(type, header, p));
    } on _Invalid catch (e) {
      return Malformed(e.reason);
    }
  }

  static const _known = {
    PacketType.discovery,
    PacketType.discoveryResponse,
    PacketType.hello,
    PacketType.goodbye,
    PacketType.nameCheck,
    PacketType.register,
    PacketType.registerResponse,
    PacketType.ping,
    PacketType.pong,
  };

  static Packet _packet(String type, PacketHeader header, _Reader p) {
    switch (type) {
      case PacketType.discovery:
        return DiscoveryPacket(header);
      case PacketType.discoveryResponse:
        return DiscoveryResponsePacket(header, _announcement(p));
      case PacketType.hello:
        return HelloPacket(header, _announcement(p));
      case PacketType.goodbye:
        return GoodbyePacket(header, reason: p.string('reason', maxLength: 64));
      case PacketType.nameCheck:
        return NameCheckPacket(
          header,
          candidateName: _requireName(
            p.string('candidateName', maxLength: 128),
            'payload.candidateName',
          ),
        );
      case PacketType.register:
        return RegisterPacket(
          header,
          name: _requireName(p.string('name', maxLength: 128), 'payload.name'),
          nameClaimedAt: p.time('nameClaimedAt'),
        );
      case PacketType.registerResponse:
        final result = switch (p.string('result', maxLength: 16)) {
          'ok' => RegisterResult.ok,
          'nameTaken' => RegisterResult.nameTaken,
          final other => throw _Invalid('payload.result "$other" is unknown'),
        };
        final taken = result == RegisterResult.nameTaken;
        return RegisterResponsePacket(
          header,
          result: result,
          name: _requireName(p.string('name', maxLength: 128), 'payload.name'),
          holderId: taken ? p.id('holderId') : p.optionalId('holderId'),
          holderClaimedAt: taken
              ? p.time('holderClaimedAt')
              : p.optionalTime('holderClaimedAt'),
        );
      case PacketType.ping:
        return PingPacket(
          header,
          nonce: p.integer('nonce', min: 0, max: 0x7FFFFFFF),
        );
      case PacketType.pong:
        return PongPacket(
          header,
          nonce: p.integer('nonce', min: 0, max: 0x7FFFFFFF),
        );
    }
    throw _Invalid('unhandled type $type');
  }

  static Announcement _announcement(_Reader p) {
    final min = p.integer('minProtocol', min: 1, max: 1000);
    final max = p.integer('maxProtocol', min: 1, max: 1000);
    if (min > max) throw const _Invalid('payload.minProtocol > maxProtocol');
    final capabilities = p.list('capabilities', maxLength: 16);
    return Announcement(
      tcpPort: p.integer('tcpPort', min: 1, max: 65535),
      appVersion: p.string('appVersion', maxLength: 32),
      nameClaimedAt: p.time('nameClaimedAt'),
      minProtocol: min,
      maxProtocol: max,
      capabilities: [
        for (final c in capabilities)
          if (c is String && c.length <= 32)
            c
          else
            throw const _Invalid('payload.capabilities must be short strings'),
      ],
    );
  }

  /// Names on the wire must already be normalised and valid.
  static String _requireName(String name, String field) {
    final validation = Username.validate(name);
    if (validation is! ValidUsername || validation.name != name) {
      throw _Invalid('$field is not a valid name');
    }
    return name;
  }

  static Map<String, Object?> _payload(Packet packet) => switch (packet) {
    DiscoveryPacket() => const {},
    DiscoveryResponsePacket(:final announcement) ||
    HelloPacket(:final announcement) => {
      'tcpPort': announcement.tcpPort,
      'appVersion': announcement.appVersion,
      'minProtocol': announcement.minProtocol,
      'maxProtocol': announcement.maxProtocol,
      'nameClaimedAt': _time(announcement.nameClaimedAt),
      'capabilities': announcement.capabilities,
    },
    GoodbyePacket(:final reason) => {'reason': reason},
    NameCheckPacket(:final candidateName) => {'candidateName': candidateName},
    RegisterPacket(:final name, :final nameClaimedAt) => {
      'name': name,
      'nameClaimedAt': _time(nameClaimedAt),
    },
    PingPacket(:final nonce) || PongPacket(:final nonce) => {'nonce': nonce},
    RegisterResponsePacket() => {
      'result': packet.result.name,
      'name': packet.name,
      if (packet.holderId != null) 'holderId': packet.holderId,
      if (packet.holderClaimedAt != null)
        'holderClaimedAt': _time(packet.holderClaimedAt!),
    },
  };

  static String _time(DateTime time) =>
      PacketHeader.wireTime(time).toIso8601String();
}

final class _Invalid implements Exception {
  const _Invalid(this.reason);

  final String reason;
}

/// Typed field access that throws [_Invalid] with the field's name.
final class _Reader {
  _Reader(this._json, {this.prefix = ''});

  final Map<String, Object?> _json;
  final String prefix;

  Object? _required(String key) {
    if (!_json.containsKey(key) || _json[key] == null) {
      throw _Invalid('$prefix$key is missing');
    }
    return _json[key];
  }

  String string(String key, {required int maxLength}) {
    final value = _required(key);
    if (value is! String) throw _Invalid('$prefix$key must be a string');
    if (value.length > maxLength) throw _Invalid('$prefix$key is too long');
    return value;
  }

  int integer(String key, {required int min, required int max}) {
    final value = _required(key);
    if (value is! int) throw _Invalid('$prefix$key must be an integer');
    if (value < min || value > max) {
      throw _Invalid('$prefix$key is out of range');
    }
    return value;
  }

  String id(String key) {
    final value = string(key, maxLength: 36);
    if (!PacketCodec.isId(value)) throw _Invalid('$prefix$key is not an ID');
    return value;
  }

  String? optionalId(String key) => _json[key] == null ? null : id(key);

  DateTime time(String key) {
    final parsed = DateTime.tryParse(string(key, maxLength: 40));
    if (parsed == null) throw _Invalid('$prefix$key is not a time');
    return PacketHeader.wireTime(parsed);
  }

  DateTime? optionalTime(String key) => _json[key] == null ? null : time(key);

  Map<String, Object?> map(String key) {
    final value = _required(key);
    if (value is! Map<String, Object?>) {
      throw _Invalid('$prefix$key must be an object');
    }
    return value;
  }

  List<Object?> list(String key, {required int maxLength}) {
    final value = _required(key);
    if (value is! List<Object?>) throw _Invalid('$prefix$key must be a list');
    if (value.length > maxLength) throw _Invalid('$prefix$key is too long');
    return value;
  }
}
