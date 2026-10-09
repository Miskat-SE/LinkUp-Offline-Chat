import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/domain/message_repository.dart';

/// [MessageRepository] on SQLite (drift). Screens watch its queries, so the
/// database is the single source of truth (PROJECT_PLAN.md §4).
final class DriftMessageRepository implements MessageRepository {
  DriftMessageRepository(this._db);

  final AppDatabase _db;

  $MessagesTable get _messages => _db.messages;

  @override
  Stream<List<ChatMessage>> watchConversation(String peerId) =>
      (_db.select(_messages)
            ..where((m) => m.conversationId.equals(peerId))
            ..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.id),
            ]))
          .watch()
          .map((rows) => rows.map(_toMessage).toList());

  /// The latest message and unread count of every chat, in one query.
  @override
  Stream<List<ConversationSummary>> watchConversations() => _db
      .customSelect(
        '''
        SELECT m.*, f.name AS file_name,
          (SELECT COUNT(*) FROM messages u
            WHERE u.conversation_id = m.conversation_id
              AND u.direction = '$_in' AND u.is_read = 0) AS unread
        FROM messages m
        LEFT JOIN files f ON f.file_id = m.file_id
        WHERE m.id = (SELECT x.id FROM messages x
            WHERE x.conversation_id = m.conversation_id
            ORDER BY x.created_at DESC, x.id DESC LIMIT 1)
        ORDER BY m.created_at DESC, m.id DESC
        ''',
        readsFrom: {_messages, _db.files},
      )
      .watch()
      .map(
        (rows) => [
          for (final row in rows)
            () {
              final last = _toMessage(
                _messages.map(row.data),
                fileName: row.readNullable<String>('file_name'),
              );
              return ConversationSummary(
                peerId: last.peerId,
                // The latest name seen in this conversation.
                peerName: last.peerName,
                lastMessage: last,
                unreadCount: row.read<int>('unread'),
              );
            }(),
        ],
      );

  @override
  Future<ChatMessage?> find(String messageId) async {
    final row = await (_db.select(
      _messages,
    )..where((m) => m.messageId.equals(messageId))).getSingleOrNull();
    return row == null ? null : _toMessage(row);
  }

  @override
  Future<bool> insertIncoming(ChatMessage message) async {
    // The unique message ID turns a resend into a no-op.
    final row = await _db
        .into(_messages)
        .insertReturningOrNull(
          _toRow(message),
          mode: InsertMode.insertOrIgnore,
        );
    return row != null;
  }

  @override
  Future<void> insertOutgoing(ChatMessage message) =>
      _db.into(_messages).insert(_toRow(message));

  @override
  Future<ChatMessage?> updateStatus(
    String messageId,
    MessageStatus status, {
    int? attempts,
  }) => _db.transaction(() async {
    final message = await find(messageId);
    if (message == null || !message.isOutgoing) return null;
    final always =
        status == MessageStatus.failed || status == MessageStatus.pending;
    final moves = always || status.rank > message.status.rank;
    if (!moves && attempts == null) return message;
    final updated = message.copyWith(
      status: moves ? status : null,
      attempts: attempts,
    );
    await (_db.update(
      _messages,
    )..where((m) => m.messageId.equals(messageId))).write(
      MessagesCompanion(
        status: Value(_statusCodes[updated.status]!),
        attempts: Value(updated.attempts),
        lastAttemptAt: status == MessageStatus.sending && moves
            ? Value(clock.now())
            : const Value.absent(),
      ),
    );
    return updated;
  });

  @override
  Future<List<String>> markRead(String peerId) => _db.transaction(() async {
    final unread = _unreadFrom(peerId);
    final ids =
        await (_db.selectOnly(_messages)
              ..addColumns([_messages.messageId])
              ..where(unread)
              ..orderBy([OrderingTerm.asc(_messages.createdAt)]))
            .map((row) => row.read(_messages.messageId)!)
            .get();
    if (ids.isNotEmpty) {
      await (_db.update(_messages)..where((_) => unread)).write(
        const MessagesCompanion(isRead: Value(true)),
      );
    }
    return ids;
  });

  @override
  Future<List<ChatMessage>> pendingFor(String peerId) async {
    final rows =
        await (_db.select(_messages)
              ..where(
                (m) =>
                    m.conversationId.equals(peerId) &
                    m.direction.equals(_out) &
                    m.status.isIn([
                      _statusCodes[MessageStatus.pending]!,
                      _statusCodes[MessageStatus.sending]!,
                    ]),
              )
              ..orderBy([
                (m) => OrderingTerm.asc(m.createdAt),
                (m) => OrderingTerm.asc(m.id),
              ]))
            .get();
    return rows.map(_toMessage).toList();
  }

  @override
  Future<int> resetInterrupted() =>
      (_db.update(_messages)..where(
            (m) => m.status.equals(_statusCodes[MessageStatus.sending]!),
          ))
          .write(
            MessagesCompanion(
              status: Value(_statusCodes[MessageStatus.pending]!),
              attempts: const Value(0),
            ),
          );

  @override
  Future<List<String>> owedReceipts(String peerId, Receipt receipt) {
    final m = _messages;
    final incoming = m.conversationId.equals(peerId) & m.direction.equals(_in);
    final owed = switch (receipt) {
      Receipt.none => const Constant(false),
      Receipt.delivered =>
        m.isRead.equals(false) &
            m.receiptSent.equals(_receiptCodes[Receipt.none]!),
      Receipt.read =>
        m.isRead.equals(true) &
            m.receiptSent.equals(_receiptCodes[Receipt.read]!).not(),
    };
    return (_db.selectOnly(m)
          ..addColumns([m.messageId])
          ..where(incoming & owed)
          ..orderBy([OrderingTerm.asc(m.createdAt), OrderingTerm.asc(m.id)]))
        .map((row) => row.read(m.messageId)!)
        .get();
  }

  @override
  Future<void> recordReceipts(List<String> messageIds, Receipt receipt) async {
    if (messageIds.isEmpty || receipt == Receipt.none) return;
    final earlier = [
      for (final r in Receipt.values)
        if (r.isBefore(receipt)) _receiptCodes[r]!,
    ];
    await (_db.update(_messages)..where(
          (m) => m.messageId.isIn(messageIds) & m.receiptSent.isIn(earlier),
        ))
        .write(MessagesCompanion(receiptSent: Value(_receiptCodes[receipt]!)));
  }

  @override
  Future<void> delete(String messageId) =>
      (_db.delete(_messages)..where((m) => m.messageId.equals(messageId))).go();

  Expression<bool> _unreadFrom(String peerId) =>
      _messages.conversationId.equals(peerId) &
      _messages.direction.equals(_in) &
      _messages.isRead.equals(false);

  // ------------------------------------------------------------- mapping

  // Stored codes are part of the schema: never change them without a
  // migration.
  static const _in = 'in';
  static const _out = 'out';
  static const _file = 'file';

  static const _statusCodes = {
    MessageStatus.pending: 'pending',
    MessageStatus.sending: 'sending',
    MessageStatus.sent: 'sent',
    MessageStatus.delivered: 'delivered',
    MessageStatus.read: 'read',
    MessageStatus.failed: 'failed',
    MessageStatus.received: 'received',
  };

  static const _receiptCodes = {
    Receipt.none: 'none',
    Receipt.delivered: 'delivered',
    Receipt.read: 'read',
  };

  static final _statusByCode = {
    for (final e in _statusCodes.entries) e.value: e.key,
  };

  static ChatMessage _toMessage(MessageRow row, {String? fileName}) =>
      ChatMessage(
        id: row.messageId,
        peerId: row.conversationId,
        peerName: row.peerName,
        direction: row.direction == _out
            ? MessageDirection.outgoing
            : MessageDirection.incoming,
        text: row.body,
        sentAt: row.sentAt,
        createdAt: row.createdAt,
        // An unknown code (from a newer version) is shown as failed, so it can
        // be retried or deleted rather than crash the chat.
        status: _statusByCode[row.status] ?? MessageStatus.failed,
        replyToId: row.replyToId,
        isRead: row.isRead,
        attempts: row.attempts,
        content: row.kind == _file ? MessageContent.file : MessageContent.text,
        fileId: row.fileId,
        fileName: fileName,
      );

  static MessagesCompanion _toRow(ChatMessage message) =>
      MessagesCompanion.insert(
        messageId: message.id,
        conversationId: message.peerId,
        peerName: message.peerName,
        direction: message.isOutgoing ? _out : _in,
        body: message.text,
        replyToId: Value(message.replyToId),
        sentAt: message.sentAt,
        createdAt: message.createdAt,
        status: _statusCodes[message.status]!,
        isRead: Value(message.isRead),
        attempts: Value(message.attempts),
        kind: Value(message.isFile ? _file : 'text'),
        fileId: Value(message.fileId),
      );
}
