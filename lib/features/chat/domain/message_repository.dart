import 'package:resqmesh/features/chat/domain/chat_message.dart';

/// Where chat messages live: SQLite on the phone, so chats and the outbox
/// survive restarts.
abstract interface class MessageRepository {
  /// One conversation, oldest first; emits on every change.
  Stream<List<ChatMessage>> watchConversation(String peerId);

  /// The chat list, most recent first; emits on every change.
  Stream<List<ConversationSummary>> watchConversations();

  Future<ChatMessage?> find(String messageId);

  /// Stores a received message. Returns false if it was already stored
  /// (a resend), so it is not shown or notified twice.
  Future<bool> insertIncoming(ChatMessage message);

  Future<void> insertOutgoing(ChatMessage message);

  /// Moves an outgoing message to [status] unless that would move it
  /// backwards (see `MessageStatus.rank`); `failed` and `pending` always
  /// apply. Returns the updated message, or null if unknown.
  Future<ChatMessage?> updateStatus(
    String messageId,
    MessageStatus status, {
    int? attempts,
  });

  /// Marks incoming messages in [conversationId] as read. Returns their IDs
  /// grouped by the device the READ receipt goes to (the Everyone thread
  /// has several senders).
  Future<Map<String, List<String>>> markRead(String conversationId);

  /// Outgoing messages to [peerId] still waiting to be sent or confirmed,
  /// oldest first.
  Future<List<ChatMessage>> pendingFor(String peerId);

  /// After a restart nothing is in flight: Sending messages go back to
  /// Pending with their attempts reset. Returns how many.
  Future<int> resetInterrupted();

  /// Incoming messages from [peerId] (in their chat or the Everyone
  /// thread) still owed [receipt], oldest first:
  /// DELIVERED for those with no receipt yet and not read, READ for read
  /// ones whose READ wasn't sent.
  Future<List<String>> owedReceipts(String peerId, Receipt receipt);

  /// Records that [receipt] was sent for [messageIds]. Never moves back.
  Future<void> recordReceipts(List<String> messageIds, Receipt receipt);

  /// Deletes on this phone only, with its recipients.
  Future<void> delete(String messageId);

  // ---------------------------------------------------------- Everyone

  /// Stores an outgoing Everyone message and who it goes to.
  Future<void> insertBroadcast(
    ChatMessage message,
    List<MessageRecipient> recipients,
  );

  Future<List<MessageRecipient>> recipients(String messageId);

  /// Recipients of every outgoing message in [conversationId], by message.
  Stream<Map<String, List<MessageRecipient>>> watchRecipients(
    String conversationId,
  );

  /// Moves one recipient forward (never back, except to failed or
  /// pending); returns the updated recipient, or null if unknown.
  Future<MessageRecipient?> updateRecipient(
    String messageId,
    String recipientId,
    MessageStatus status, {
    int? attempts,
  });

  /// Everyone messages still to be sent or confirmed to [peerId], oldest
  /// first.
  Future<List<(ChatMessage, MessageRecipient)>> pendingDeliveriesTo(
    String peerId,
  );
}
