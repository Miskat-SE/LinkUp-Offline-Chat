/// Whether this device sent or received a message.
enum MessageDirection { incoming, outgoing }

/// What a message carries.
enum MessageContent { text, file }

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
  });

  /// Message ID; the same on both phones.
  final String id;

  /// The other person in the conversation.
  final String peerId;

  /// Their name when the message was sent or received, so the chat list
  /// works while they are offline.
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

  bool get isOutgoing => direction == MessageDirection.outgoing;

  bool get isFile => content == MessageContent.file;

  /// One line for the chat list and notifications.
  String get preview => isFile ? '📎 ${fileName ?? 'File'}' : text;

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
  );
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
