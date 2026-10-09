import 'dart:async';

import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/domain/message_repository.dart';

/// [MessageRepository] kept in memory. Messages are lost when the app
/// closes; P5 replaces this with SQLite.
final class InMemoryMessageRepository implements MessageRepository {
  final Map<String, ChatMessage> _messages = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<ChatMessage>> watchConversation(String peerId) =>
      _watch(() => _conversation(peerId));

  @override
  Stream<List<ConversationSummary>> watchConversations() => _watch(_summaries);

  @override
  Future<ChatMessage?> find(String messageId) async => _messages[messageId];

  /// Synchronous lookup, for tests.
  ChatMessage? peek(String messageId) => _messages[messageId];

  @override
  Future<bool> insertIncoming(ChatMessage message) async {
    final existing = _messages[message.id];
    // Same ID from the same person: a resend. (A clash with another
    // person's ID is not trusted either.)
    if (existing != null) return false;
    _messages[message.id] = message;
    _changed();
    return true;
  }

  @override
  Future<void> insertOutgoing(ChatMessage message) async {
    _messages[message.id] = message;
    _changed();
  }

  @override
  Future<ChatMessage?> updateStatus(
    String messageId,
    MessageStatus status, {
    int? attempts,
  }) async {
    final message = _messages[messageId];
    if (message == null || !message.isOutgoing) return null;
    final always =
        status == MessageStatus.failed || status == MessageStatus.pending;
    if (!always && status.rank <= message.status.rank) {
      if (attempts == null) return message;
      return _messages[messageId] = message.copyWith(attempts: attempts);
    }
    final updated = message.copyWith(status: status, attempts: attempts);
    _messages[messageId] = updated;
    _changed();
    return updated;
  }

  @override
  Future<List<String>> markRead(String peerId) async {
    final ids = <String>[];
    for (final m in _messages.values.toList()) {
      if (m.peerId == peerId && !m.isOutgoing && !m.isRead) {
        _messages[m.id] = m.copyWith(isRead: true);
        ids.add(m.id);
      }
    }
    if (ids.isNotEmpty) _changed();
    return ids;
  }

  @override
  Future<List<ChatMessage>> pendingFor(String peerId) async =>
      _conversation(peerId)
          .where(
            (m) =>
                m.isOutgoing &&
                (m.status == MessageStatus.pending ||
                    m.status == MessageStatus.sending),
          )
          .toList();

  @override
  Future<void> delete(String messageId) async {
    if (_messages.remove(messageId) != null) _changed();
  }

  List<ChatMessage> _conversation(String peerId) =>
      _messages.values.where((m) => m.peerId == peerId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<ConversationSummary> _summaries() {
    final byPeer = <String, List<ChatMessage>>{};
    for (final m in _messages.values) {
      byPeer.putIfAbsent(m.peerId, () => []).add(m);
    }
    final summaries =
        [
          for (final entry in byPeer.entries)
            () {
              final messages = entry.value
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              final last = messages.last;
              return ConversationSummary(
                peerId: entry.key,
                // The latest name seen in this conversation.
                peerName: last.peerName,
                lastMessage: last,
                unreadCount: messages
                    .where((m) => !m.isOutgoing && !m.isRead)
                    .length,
              );
            }(),
        ]..sort(
          (a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt),
        );
    return summaries;
  }

  /// Emits the current value at once, then after every change.
  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    yield* _changes.stream.map((_) => read());
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
