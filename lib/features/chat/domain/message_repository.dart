import 'package:resqmesh/features/chat/domain/chat_message.dart';

/// Where chat messages live. In memory for now; SQLite in P5, behind the
/// same interface.
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

  /// Marks incoming messages from [peerId] as read and returns their IDs.
  Future<List<String>> markRead(String peerId);

  /// Outgoing messages to [peerId] still waiting to be sent, oldest first.
  Future<List<ChatMessage>> pendingFor(String peerId);

  /// Deletes on this phone only.
  Future<void> delete(String messageId);
}
