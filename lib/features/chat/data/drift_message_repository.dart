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
                peerName: last.peerId == _everyone ? 'Everyone' : last.peerName,
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
  Future<Map<String, List<String>>> markRead(String conversationId) =>
      _db.transaction(() async {
        final unread = _unreadFrom(conversationId);
        final m = _messages;
        final rows =
            await (_db.selectOnly(m)
                  ..addColumns([m.messageId, m.conversationId, m.senderId])
                  ..where(unread)
                  ..orderBy([OrderingTerm.asc(m.createdAt)]))
                .get();
        if (rows.isEmpty) return const {};
        await (_db.update(m)..where((_) => unread)).write(
          const MessagesCompanion(isRead: Value(true)),
        );
        final bySender = <String, List<String>>{};
        for (final row in rows) {
          // Everyone messages are confirmed to whoever sent each one.
          final sender = row.read(m.senderId) ?? row.read(m.conversationId)!;
          bySender.putIfAbsent(sender, () => []).add(row.read(m.messageId)!);
        }
        return bySender;
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
  Future<int> resetInterrupted() => _db.transaction(() async {
    final sending = _statusCodes[MessageStatus.sending]!;
    final pending = _statusCodes[MessageStatus.pending]!;
    final messages =
        await (_db.update(
          _messages,
        )..where((m) => m.status.equals(sending))).write(
          MessagesCompanion(status: Value(pending), attempts: const Value(0)),
        );
    final deliveries =
        await (_db.update(
          _recipients,
        )..where((r) => r.status.equals(sending))).write(
          MessageRecipientsCompanion(
            status: Value(pending),
            attempts: const Value(0),
            updatedAt: Value(clock.now()),
          ),
        );
    return messages + deliveries;
  });

  @override
  Future<List<String>> owedReceipts(String peerId, Receipt receipt) {
    final m = _messages;
    // Their chat, and their messages in the Everyone thread.
    final incoming =
        (m.conversationId.equals(peerId) | m.senderId.equals(peerId)) &
        m.direction.equals(_in);
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
  Future<void> delete(String messageId) => _db.transaction(() async {
    await (_db.delete(
      _recipients,
    )..where((r) => r.messageId.equals(messageId))).go();
    await (_db.delete(
      _messages,
    )..where((m) => m.messageId.equals(messageId))).go();
  });

  // ---------------------------------------------------------- Everyone

  $MessageRecipientsTable get _recipients => _db.messageRecipients;

  @override
  Future<void> insertBroadcast(
    ChatMessage message,
    List<MessageRecipient> recipients,
  ) => _db.transaction(() async {
    await _db.into(_messages).insert(_toRow(message));
    final now = clock.now();
    for (final r in recipients) {
      await _db
          .into(_recipients)
          .insert(
            MessageRecipientsCompanion.insert(
              messageId: message.id,
              recipientId: r.recipientId,
              recipientName: r.recipientName,
              status: _statusCodes[r.status]!,
              attempts: Value(r.attempts),
              fileId: Value(r.fileId),
              updatedAt: now,
            ),
          );
    }
  });

  @override
  Future<List<MessageRecipient>> recipients(String messageId) async {
    final rows =
        await (_db.select(_recipients)
              ..where((r) => r.messageId.equals(messageId))
              ..orderBy([(r) => OrderingTerm.asc(r.recipientName)]))
            .get();
    return rows.map(_toRecipient).toList();
  }

  @override
  Stream<Map<String, List<MessageRecipient>>> watchRecipients(
    String conversationId,
  ) {
    final query =
        _db.select(_recipients).join([
            innerJoin(
              _messages,
              _messages.messageId.equalsExp(_recipients.messageId),
            ),
          ])
          ..where(_messages.conversationId.equals(conversationId))
          ..orderBy([OrderingTerm.asc(_recipients.recipientName)]);
    return query.watch().map((rows) {
      final byMessage = <String, List<MessageRecipient>>{};
      for (final row in rows) {
        final recipient = _toRecipient(row.readTable(_recipients));
        byMessage.putIfAbsent(recipient.messageId, () => []).add(recipient);
      }
      return byMessage;
    });
  }

  @override
  Future<MessageRecipient?> updateRecipient(
    String messageId,
    String recipientId,
    MessageStatus status, {
    int? attempts,
  }) => _db.transaction(() async {
    final where =
        _recipients.messageId.equals(messageId) &
        _recipients.recipientId.equals(recipientId);
    final row = await (_db.select(
      _recipients,
    )..where((_) => where)).getSingleOrNull();
    if (row == null) return null;
    final current = _toRecipient(row);
    final always =
        status == MessageStatus.failed || status == MessageStatus.pending;
    final moves = always || status.rank > current.status.rank;
    if (!moves && attempts == null) return current;
    final updated = current.copyWith(
      status: moves ? status : null,
      attempts: attempts,
    );
    await (_db.update(_recipients)..where((_) => where)).write(
      MessageRecipientsCompanion(
        status: Value(_statusCodes[updated.status]!),
        attempts: Value(updated.attempts),
        updatedAt: Value(clock.now()),
      ),
    );
    return updated;
  });

  @override
  Future<List<(ChatMessage, MessageRecipient)>> pendingDeliveriesTo(
    String peerId,
  ) async {
    final query =
        _db.select(_recipients).join([
            innerJoin(
              _messages,
              _messages.messageId.equalsExp(_recipients.messageId),
            ),
          ])
          ..where(
            _recipients.recipientId.equals(peerId) &
                _recipients.status.isIn([
                  _statusCodes[MessageStatus.pending]!,
                  _statusCodes[MessageStatus.sending]!,
                ]),
          )
          ..orderBy([
            OrderingTerm.asc(_messages.createdAt),
            OrderingTerm.asc(_messages.id),
          ]);
    return [
      for (final row in await query.get())
        (
          _toMessage(row.readTable(_messages)),
          _toRecipient(row.readTable(_recipients)),
        ),
    ];
  }

  static MessageRecipient _toRecipient(RecipientRow row) => MessageRecipient(
    messageId: row.messageId,
    recipientId: row.recipientId,
    recipientName: row.recipientName,
    status: _statusByCode[row.status] ?? MessageStatus.failed,
    attempts: row.attempts,
    fileId: row.fileId,
  );

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
  static const _everyone = 'everyone';

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
        audience: row.audience == _everyone
            ? ChatAudience.everyone
            : ChatAudience.direct,
        senderId: row.senderId,
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
        audience: Value(message.isBroadcast ? _everyone : 'direct'),
        senderId: Value(message.senderId),
      );
}
