/// Whether this device sent or received a message.
enum MessageDirection { incoming, outgoing }

/// What a message carries.
enum MessageContent { text, file }

/// Who a message is for.
enum ChatAudience {
  /// One person (also each copy of a message sent to selected people).
  direct,

  /// Everyone online at the time; shown in the Everyone thread.
  everyone,
}

/// Delivery state of a message (spec §8, PROTOCOL.md §4.3).
///
/// Outgoing messages move forward only:
/// pending → sending → sent → delivered → read, or to failed.
enum MessageStatus {
  /// The other person is offline; waiting to send.
  pending,

  /// On its way; waiting for the other phone to confirm.
  sending,

  /// The other phone stored it.
  sent,

  /// The other person was shown it.
  delivered,

  /// The other person opened the chat.
  read,

  /// Gave up after repeated attempts; can be retried.
  failed,

  /// An incoming message.
  received;

  /// Outgoing progress order, used so late receipts never move a message
  /// backwards (a READ before its DELIVERED stays read).
  int get rank => switch (this) {
    pending || failed => 0,
    sending => 1,
    sent => 2,
    delivered => 3,
    read => 4,
    received => 0,
  };
}

/// The last receipt sent back for an incoming message. Receipts that
/// couldn't be sent (the sender was offline) go out when they reconnect.
enum Receipt {
  none,
  delivered,
  read;

  bool isBefore(Receipt other) => index < other.index;
}

/// One chat message. Pure data; the repository stores it.
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.direction,
    required this.text,
    required this.sentAt,
    required this.createdAt,
    required this.status,
    this.replyToId,
    this.isRead = false,
    this.attempts = 0,
    this.content = MessageContent.text,
    this.fileId,
    this.fileName,
    this.audience = ChatAudience.direct,
    this.senderId,
    this.deletedAt,
    this.mentions = const [],
    this.voiceMs,
  });

  /// The conversation ID of the Everyone thread.
  static const everyone = 'everyone';

  /// Message ID; the same on both phones.
  final String id;

  /// The conversation: the other person's device ID, or [everyone].
  final String peerId;

  /// Direct messages: the other person's name when it was sent or
  /// received, so the chat list works while they are offline. Incoming
  /// Everyone messages: the sender's name. Outgoing ones: "Everyone".
  final String peerName;
  final MessageDirection direction;
  final String text;

  /// The sender's clock; shown, but never used for ordering.
  final DateTime sentAt;

  /// This phone's clock when the message was created or received. Chats are
  /// ordered by this, because phones' clocks differ.
  final DateTime createdAt;
  final MessageStatus status;
  final String? replyToId;

  /// Incoming only: this person has opened the chat since it arrived.
  final bool isRead;

  /// Outgoing only: how many times it has been sent.
  final int attempts;
  final MessageContent content;

  /// File messages: the shared file, and its name where a query includes
  /// it (the chat list, new-message notifications).
  final String? fileId;
  final String? fileName;
  final ChatAudience audience;

  /// Incoming Everyone messages: who sent it.
  final String? senderId;

  /// Deleted for everyone (P15.4).
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Everyone messages: device IDs @mentioned (P15.5).
  final List<String> mentions;

  /// Voice messages (P15.7): a file message this long.
  final int? voiceMs;

  bool get isVoice => voiceMs != null;

  bool get isOutgoing => direction == MessageDirection.outgoing;

  bool get isBroadcast => audience == ChatAudience.everyone;

  /// The device receipts for this message go to (incoming only).
  String get sender => senderId ?? peerId;

  bool get isFile => content == MessageContent.file;

  /// One line for the chat list and notifications.
  String get preview =>
      // In the Everyone thread, say who wrote it.
      isBroadcast && !isOutgoing ? '$peerName: $body' : body;

  /// The text, or the file's name.
  String get body => isDeleted
      ? (isOutgoing ? 'You deleted this message' : 'This message was deleted')
      : isVoice
      ? '🎤 Voice message (${voiceLength(voiceMs!)})'
      : isFile
      ? '📎 ${fileName ?? 'File'}'
      : text;

  ChatMessage copyWith({
    String? peerName,
    MessageStatus? status,
    bool? isRead,
    int? attempts,
  }) => ChatMessage(
    id: id,
    peerId: peerId,
    peerName: peerName ?? this.peerName,
    direction: direction,
    text: text,
    sentAt: sentAt,
    createdAt: createdAt,
    status: status ?? this.status,
    replyToId: replyToId,
    isRead: isRead ?? this.isRead,
    attempts: attempts ?? this.attempts,
    content: content,
    fileId: fileId,
    fileName: fileName,
    audience: audience,
    senderId: senderId,
    deletedAt: deletedAt,
    mentions: mentions,
    voiceMs: voiceMs,
  );
}

/// One person an Everyone message was sent to, with their own status.
final class MessageRecipient {
  const MessageRecipient({
    required this.messageId,
    required this.recipientId,
    required this.recipientName,
    required this.status,
    this.attempts = 0,
    this.fileId,
  });

  final String messageId;
  final String recipientId;
  final String recipientName;

  /// pending, sending, sent, delivered, read or failed.
  final MessageStatus status;
  final int attempts;

  /// File messages: this recipient's own transfer.
  final String? fileId;

  MessageRecipient copyWith({MessageStatus? status, int? attempts}) =>
      MessageRecipient(
        messageId: messageId,
        recipientId: recipientId,
        recipientName: recipientName,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        fileId: fileId,
      );
}

/// "Delivered to 2 of 3", for an Everyone message's bubble.
final class DeliverySummary {
  const DeliverySummary(this.recipients);

  final List<MessageRecipient> recipients;

  int get total => recipients.length;

  int count(MessageStatus atLeast) => recipients
      .where(
        (r) =>
            r.status != MessageStatus.failed && r.status.rank >= atLeast.rank,
      )
      .length;

  int get failed =>
      recipients.where((r) => r.status == MessageStatus.failed).length;

  /// The status every recipient has reached, for the bubble's tick.
  MessageStatus get overall {
    if (recipients.isEmpty) return MessageStatus.sent;
    if (failed == total) return MessageStatus.failed;
    var lowest = MessageStatus.read;
    for (final r in recipients) {
      if (r.status == MessageStatus.failed) continue;
      if (r.status.rank < lowest.rank) lowest = r.status;
    }
    return lowest;
  }

  /// How many people have seen it (P15.1); shown beside [label].
  int get seen => count(MessageStatus.read);

  /// How far it got: sending, sent or delivered, and failures. Who has seen
  /// it is [seen].
  String get label {
    if (total == 0) return 'Nobody was online';
    final delivered = count(MessageStatus.delivered);
    final sent = count(MessageStatus.sent);
    final parts = <String>[
      if (delivered > 0)
        'Delivered to $delivered of $total'
      else if (sent > 0)
        'Sent to $sent of $total'
      else
        'Sending to $total',
      if (failed > 0) '$failed not sent',
    ];
    return parts.join(' · ');
  }
}

/// A row in the chat list.
final class ConversationSummary {
  const ConversationSummary({
    required this.peerId,
    required this.peerName,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String peerId;
  final String peerName;
  final ChatMessage lastMessage;
  final int unreadCount;
}

/// A count in a few characters: 999, 1k, 1.5k, 12k, 1.2M.
String compactCount(int n) {
  String short(double value, String unit) {
    final text = value >= 10
        ? value.floor().toString()
        : value.toStringAsFixed(1);
    return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}$unit';
  }

  if (n < 1000) return '$n';
  if (n < 1000000) return short((n ~/ 100) / 10, 'k');
  return short((n ~/ 100000) / 10, 'M');
}

/// A voice message's length: 0:07, 1:42, 10:00.
String voiceLength(int ms) {
  final seconds = (ms / 1000).round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
