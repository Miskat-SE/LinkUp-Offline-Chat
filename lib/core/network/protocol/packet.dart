import 'package:clock/clock.dart';
import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:uuid/uuid.dart';

/// Wire names of the packet types (PROTOCOL.md §4).
abstract final class PacketType {
  static const discovery = 'DISCOVERY';
  static const discoveryResponse = 'DISCOVERY_RESPONSE';
  static const hello = 'HELLO';
  static const goodbye = 'GOODBYE';
  static const nameCheck = 'NAME_CHECK';
  static const register = 'REGISTER';
  static const registerResponse = 'REGISTER_RESPONSE';
  static const ping = 'PING';
  static const pong = 'PONG';
  static const message = 'MESSAGE';
  static const messageAck = 'MESSAGE_ACK';
  static const messageDelivered = 'MESSAGE_DELIVERED';
  static const messageRead = 'MESSAGE_READ';
}

/// Envelope fields shared by every control packet (PROTOCOL.md §3).
final class PacketHeader {
  const PacketHeader({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.timestamp,
  });

  /// A header for a new packet from this device, with a fresh message ID.
  factory PacketHeader.create({
    required String senderId,
    required String senderName,
    String receiverId = everyone,
  }) => PacketHeader(
    messageId: _uuid.v4(),
    senderId: senderId,
    senderName: senderName,
    receiverId: receiverId,
    timestamp: wireTime(clock.now()),
  );

  static const everyone = '*';
  static const _uuid = Uuid();

  final String messageId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final DateTime timestamp;

  /// UTC with millisecond precision, as written on the wire.
  static DateTime wireTime(DateTime time) =>
      DateTime.fromMillisecondsSinceEpoch(
        time.millisecondsSinceEpoch,
        isUtc: true,
      );

  @override
  bool operator ==(Object other) =>
      other is PacketHeader &&
      other.messageId == messageId &&
      other.senderId == senderId &&
      other.senderName == senderName &&
      other.receiverId == receiverId &&
      other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(messageId, senderId, senderName, receiverId, timestamp);
}

/// Every packet on the wire; one final subclass per type.
sealed class Packet {
  const Packet(this.header);

  final PacketHeader header;

  String get type;

  int get protocolVersion => ProtocolConstants.version;
}

/// What a device says about itself in HELLO and DISCOVERY_RESPONSE.
final class Announcement {
  const Announcement({
    required this.tcpPort,
    required this.appVersion,
    required this.nameClaimedAt,
    this.minProtocol = ProtocolConstants.version,
    this.maxProtocol = ProtocolConstants.version,
    this.capabilities = const [],
  });

  final int tcpPort;
  final String appVersion;
  final DateTime nameClaimedAt;
  final int minProtocol;
  final int maxProtocol;
  final List<String> capabilities;

  /// Whether this build can talk to the announcing device.
  bool get compatible =>
      minProtocol <= ProtocolConstants.version &&
      maxProtocol >= ProtocolConstants.version;

  @override
  bool operator ==(Object other) =>
      other is Announcement &&
      other.tcpPort == tcpPort &&
      other.appVersion == appVersion &&
      other.nameClaimedAt == nameClaimedAt &&
      other.minProtocol == minProtocol &&
      other.maxProtocol == maxProtocol &&
      _listEquals(other.capabilities, capabilities);

  @override
  int get hashCode => Object.hash(
    tcpPort,
    appVersion,
    nameClaimedAt,
    minProtocol,
    maxProtocol,
    Object.hashAll(capabilities),
  );
}

/// "Who is here?"
final class DiscoveryPacket extends Packet {
  const DiscoveryPacket(super.header);

  @override
  String get type => PacketType.discovery;
}

/// Answer to [DiscoveryPacket], sent straight back to the asker.
final class DiscoveryResponsePacket extends Packet {
  const DiscoveryResponsePacket(super.header, this.announcement);

  final Announcement announcement;

  @override
  String get type => PacketType.discoveryResponse;
}

/// Periodic announcement; also the first frame on every TCP connection.
final class HelloPacket extends Packet {
  const HelloPacket(super.header, this.announcement);

  final Announcement announcement;

  @override
  String get type => PacketType.hello;
}

final class GoodbyePacket extends Packet {
  const GoodbyePacket(super.header, {required this.reason});

  final String reason;

  @override
  String get type => PacketType.goodbye;
}

/// "Is this name taken?" Only a device holding the name answers.
final class NameCheckPacket extends Packet {
  const NameCheckPacket(super.header, {required this.candidateName});

  final String candidateName;

  @override
  String get type => PacketType.nameCheck;
}

final class RegisterPacket extends Packet {
  const RegisterPacket(
    super.header, {
    required this.name,
    required this.nameClaimedAt,
  });

  final String name;
  final DateTime nameClaimedAt;

  @override
  String get type => PacketType.register;
}

enum RegisterResult { ok, nameTaken }

final class RegisterResponsePacket extends Packet {
  const RegisterResponsePacket(
    super.header, {
    required this.result,
    required this.name,
    this.holderId,
    this.holderClaimedAt,
  });

  final RegisterResult result;
  final String name;
  final String? holderId;
  final DateTime? holderClaimedAt;

  @override
  String get type => PacketType.registerResponse;
}

/// Keep-alive on an idle TCP connection (PROTOCOL.md §4.5).
final class PingPacket extends Packet {
  const PingPacket(super.header, {required this.nonce});

  final int nonce;

  @override
  String get type => PacketType.ping;
}

/// Answer to [PingPacket], echoing its nonce.
final class PongPacket extends Packet {
  const PongPacket(super.header, {required this.nonce});

  final int nonce;

  @override
  String get type => PacketType.pong;
}

enum MessageKind { text, file }

/// Who a chat message was sent to (PROTOCOL.md §4.3).
enum MessageAudience {
  /// One person.
  direct,

  /// Everyone online at the time.
  broadcast,

  /// Several selected people.
  multi,
}

/// The file a `file` message announces; the data follows separately (P6).
final class FileRef {
  const FileRef({
    required this.fileId,
    required this.name,
    required this.size,
    required this.mimeType,
    required this.sha256,
  });

  final String fileId;
  final String name;
  final int size;
  final String mimeType;
  final String sha256;
}

/// A chat message. The envelope's message ID is the chat message's ID and
/// stays the same when it is resent.
final class MessagePacket extends Packet {
  const MessagePacket(
    super.header, {
    required this.kind,
    required this.audience,
    this.text,
    this.replyToId,
    this.file,
  });

  final MessageKind kind;
  final MessageAudience audience;
  final String? text;
  final String? replyToId;
  final FileRef? file;

  @override
  String get type => PacketType.message;
}

/// The receiver validated and stored [ackFor]: the sender shows it as Sent.
final class MessageAckPacket extends Packet {
  const MessageAckPacket(super.header, {required this.ackFor});

  final String ackFor;

  @override
  String get type => PacketType.messageAck;
}

/// The messages were shown to the recipient: Delivered.
final class MessageDeliveredPacket extends Packet {
  const MessageDeliveredPacket(super.header, {required this.messageIds});

  final List<String> messageIds;

  @override
  String get type => PacketType.messageDelivered;
}

/// The recipient opened the chat: Read.
final class MessageReadPacket extends Packet {
  const MessageReadPacket(super.header, {required this.messageIds});

  final List<String> messageIds;

  @override
  String get type => PacketType.messageRead;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
