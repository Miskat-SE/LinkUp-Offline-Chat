// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerNameMeta = const VerificationMeta(
    'peerName',
  );
  @override
  late final GeneratedColumn<String> peerName = GeneratedColumn<String>(
    'peer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audienceMeta = const VerificationMeta(
    'audience',
  );
  @override
  late final GeneratedColumn<String> audience = GeneratedColumn<String>(
    'audience',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('direct'),
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> sentAt =
      GeneratedColumn<int>(
        'sent_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessagesTable.$convertersentAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessagesTable.$convertercreatedAt);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
    'is_read',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _receiptSentMeta = const VerificationMeta(
    'receiptSent',
  );
  @override
  late final GeneratedColumn<String> receiptSent = GeneratedColumn<String>(
    'receipt_sent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastAttemptAt =
      GeneratedColumn<int>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MessagesTable.$converterlastAttemptAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> deletedAt =
      GeneratedColumn<int>(
        'deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MessagesTable.$converterdeletedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    conversationId,
    peerName,
    direction,
    kind,
    body,
    fileId,
    audience,
    senderId,
    replyToId,
    sentAt,
    createdAt,
    status,
    isRead,
    receiptSent,
    attempts,
    lastAttemptAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('peer_name')) {
      context.handle(
        _peerNameMeta,
        peerName.isAcceptableOrUnknown(data['peer_name']!, _peerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_peerNameMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    }
    if (data.containsKey('audience')) {
      context.handle(
        _audienceMeta,
        audience.isAcceptableOrUnknown(data['audience']!, _audienceMeta),
      );
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_read')) {
      context.handle(
        _isReadMeta,
        isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta),
      );
    }
    if (data.containsKey('receipt_sent')) {
      context.handle(
        _receiptSentMeta,
        receiptSent.isAcceptableOrUnknown(
          data['receipt_sent']!,
          _receiptSentMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      peerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_name'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      ),
      audience: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audience'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      sentAt: $MessagesTable.$convertersentAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}sent_at'],
        )!,
      ),
      createdAt: $MessagesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isRead: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read'],
      )!,
      receiptSent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_sent'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastAttemptAt: $MessagesTable.$converterlastAttemptAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_attempt_at'],
        ),
      ),
      deletedAt: $MessagesTable.$converterdeletedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}deleted_at'],
        ),
      ),
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertersentAt = const UtcMicros();
  static TypeConverter<DateTime, int> $convertercreatedAt = const UtcMicros();
  static TypeConverter<DateTime, int> $converterlastAttemptAt =
      const UtcMicros();
  static TypeConverter<DateTime?, int?> $converterlastAttemptAtn =
      NullAwareTypeConverter.wrap($converterlastAttemptAt);
  static TypeConverter<DateTime, int> $converterdeletedAt = const UtcMicros();
  static TypeConverter<DateTime?, int?> $converterdeletedAtn =
      NullAwareTypeConverter.wrap($converterdeletedAt);
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  final int id;

  /// The ID on the wire; the same on both phones.
  final String messageId;

  /// The other person's device ID.
  final String conversationId;

  /// Their name when the message was sent or received.
  final String peerName;

  /// `in` or `out`.
  final String direction;

  /// `text` or `file` (schema v2).
  final String kind;

  /// The text; empty for a file message.
  final String body;

  /// File messages only: the row in [Files] (schema v2).
  final String? fileId;

  /// `direct` or `everyone` (schema v3).
  final String audience;

  /// Incoming Everyone messages: the sender's device ID (schema v3).
  final String? senderId;
  final String? replyToId;

  /// The sender's clock; shown, never used for ordering.
  final DateTime sentAt;

  /// This phone's clock; chats are ordered by it.
  final DateTime createdAt;

  /// `pending`, `sending`, `sent`, `delivered`, `read`, `failed` or
  /// `received` (§7.4).
  final String status;

  /// Incoming only: the chat was opened since it arrived.
  final bool isRead;

  /// Incoming only: the last receipt sent back, `none`, `delivered` or
  /// `read`. Receipts that couldn't be sent go out on reconnect.
  final String receiptSent;

  /// Outgoing only: send attempts on the current connection.
  final int attempts;
  final DateTime? lastAttemptAt;

  /// Deleted for everyone (P15.4, schema v4): the text is wiped and the
  /// bubble says so. Outgoing ones are re-announced to recipients who come
  /// back within a week.
  final DateTime? deletedAt;
  const MessageRow({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.peerName,
    required this.direction,
    required this.kind,
    required this.body,
    this.fileId,
    required this.audience,
    this.senderId,
    this.replyToId,
    required this.sentAt,
    required this.createdAt,
    required this.status,
    required this.isRead,
    required this.receiptSent,
    required this.attempts,
    this.lastAttemptAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['peer_name'] = Variable<String>(peerName);
    map['direction'] = Variable<String>(direction);
    map['kind'] = Variable<String>(kind);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || fileId != null) {
      map['file_id'] = Variable<String>(fileId);
    }
    map['audience'] = Variable<String>(audience);
    if (!nullToAbsent || senderId != null) {
      map['sender_id'] = Variable<String>(senderId);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    {
      map['sent_at'] = Variable<int>(
        $MessagesTable.$convertersentAt.toSql(sentAt),
      );
    }
    {
      map['created_at'] = Variable<int>(
        $MessagesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    map['status'] = Variable<String>(status);
    map['is_read'] = Variable<bool>(isRead);
    map['receipt_sent'] = Variable<String>(receiptSent);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<int>(
        $MessagesTable.$converterlastAttemptAtn.toSql(lastAttemptAt),
      );
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(
        $MessagesTable.$converterdeletedAtn.toSql(deletedAt),
      );
    }
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      peerName: Value(peerName),
      direction: Value(direction),
      kind: Value(kind),
      body: Value(body),
      fileId: fileId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileId),
      audience: Value(audience),
      senderId: senderId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderId),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      sentAt: Value(sentAt),
      createdAt: Value(createdAt),
      status: Value(status),
      isRead: Value(isRead),
      receiptSent: Value(receiptSent),
      attempts: Value(attempts),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<int>(json['id']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      peerName: serializer.fromJson<String>(json['peerName']),
      direction: serializer.fromJson<String>(json['direction']),
      kind: serializer.fromJson<String>(json['kind']),
      body: serializer.fromJson<String>(json['body']),
      fileId: serializer.fromJson<String?>(json['fileId']),
      audience: serializer.fromJson<String>(json['audience']),
      senderId: serializer.fromJson<String?>(json['senderId']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      receiptSent: serializer.fromJson<String>(json['receiptSent']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'peerName': serializer.toJson<String>(peerName),
      'direction': serializer.toJson<String>(direction),
      'kind': serializer.toJson<String>(kind),
      'body': serializer.toJson<String>(body),
      'fileId': serializer.toJson<String?>(fileId),
      'audience': serializer.toJson<String>(audience),
      'senderId': serializer.toJson<String?>(senderId),
      'replyToId': serializer.toJson<String?>(replyToId),
      'sentAt': serializer.toJson<DateTime>(sentAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'isRead': serializer.toJson<bool>(isRead),
      'receiptSent': serializer.toJson<String>(receiptSent),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  MessageRow copyWith({
    int? id,
    String? messageId,
    String? conversationId,
    String? peerName,
    String? direction,
    String? kind,
    String? body,
    Value<String?> fileId = const Value.absent(),
    String? audience,
    Value<String?> senderId = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    DateTime? sentAt,
    DateTime? createdAt,
    String? status,
    bool? isRead,
    String? receiptSent,
    int? attempts,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => MessageRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    peerName: peerName ?? this.peerName,
    direction: direction ?? this.direction,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    fileId: fileId.present ? fileId.value : this.fileId,
    audience: audience ?? this.audience,
    senderId: senderId.present ? senderId.value : this.senderId,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    sentAt: sentAt ?? this.sentAt,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    isRead: isRead ?? this.isRead,
    receiptSent: receiptSent ?? this.receiptSent,
    attempts: attempts ?? this.attempts,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      peerName: data.peerName.present ? data.peerName.value : this.peerName,
      direction: data.direction.present ? data.direction.value : this.direction,
      kind: data.kind.present ? data.kind.value : this.kind,
      body: data.body.present ? data.body.value : this.body,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      audience: data.audience.present ? data.audience.value : this.audience,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      receiptSent: data.receiptSent.present
          ? data.receiptSent.value
          : this.receiptSent,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerName: $peerName, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('fileId: $fileId, ')
          ..write('audience: $audience, ')
          ..write('senderId: $senderId, ')
          ..write('replyToId: $replyToId, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('receiptSent: $receiptSent, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    messageId,
    conversationId,
    peerName,
    direction,
    kind,
    body,
    fileId,
    audience,
    senderId,
    replyToId,
    sentAt,
    createdAt,
    status,
    isRead,
    receiptSent,
    attempts,
    lastAttemptAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.peerName == this.peerName &&
          other.direction == this.direction &&
          other.kind == this.kind &&
          other.body == this.body &&
          other.fileId == this.fileId &&
          other.audience == this.audience &&
          other.senderId == this.senderId &&
          other.replyToId == this.replyToId &&
          other.sentAt == this.sentAt &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.isRead == this.isRead &&
          other.receiptSent == this.receiptSent &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.deletedAt == this.deletedAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<int> id;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> peerName;
  final Value<String> direction;
  final Value<String> kind;
  final Value<String> body;
  final Value<String?> fileId;
  final Value<String> audience;
  final Value<String?> senderId;
  final Value<String?> replyToId;
  final Value<DateTime> sentAt;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<bool> isRead;
  final Value<String> receiptSent;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> deletedAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.peerName = const Value.absent(),
    this.direction = const Value.absent(),
    this.kind = const Value.absent(),
    this.body = const Value.absent(),
    this.fileId = const Value.absent(),
    this.audience = const Value.absent(),
    this.senderId = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isRead = const Value.absent(),
    this.receiptSent = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String messageId,
    required String conversationId,
    required String peerName,
    required String direction,
    this.kind = const Value.absent(),
    required String body,
    this.fileId = const Value.absent(),
    this.audience = const Value.absent(),
    this.senderId = const Value.absent(),
    this.replyToId = const Value.absent(),
    required DateTime sentAt,
    required DateTime createdAt,
    required String status,
    this.isRead = const Value.absent(),
    this.receiptSent = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : messageId = Value(messageId),
       conversationId = Value(conversationId),
       peerName = Value(peerName),
       direction = Value(direction),
       body = Value(body),
       sentAt = Value(sentAt),
       createdAt = Value(createdAt),
       status = Value(status);
  static Insertable<MessageRow> custom({
    Expression<int>? id,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? peerName,
    Expression<String>? direction,
    Expression<String>? kind,
    Expression<String>? body,
    Expression<String>? fileId,
    Expression<String>? audience,
    Expression<String>? senderId,
    Expression<String>? replyToId,
    Expression<int>? sentAt,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<bool>? isRead,
    Expression<String>? receiptSent,
    Expression<int>? attempts,
    Expression<int>? lastAttemptAt,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (peerName != null) 'peer_name': peerName,
      if (direction != null) 'direction': direction,
      if (kind != null) 'kind': kind,
      if (body != null) 'body': body,
      if (fileId != null) 'file_id': fileId,
      if (audience != null) 'audience': audience,
      if (senderId != null) 'sender_id': senderId,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (sentAt != null) 'sent_at': sentAt,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (isRead != null) 'is_read': isRead,
      if (receiptSent != null) 'receipt_sent': receiptSent,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? peerName,
    Value<String>? direction,
    Value<String>? kind,
    Value<String>? body,
    Value<String?>? fileId,
    Value<String>? audience,
    Value<String?>? senderId,
    Value<String?>? replyToId,
    Value<DateTime>? sentAt,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<bool>? isRead,
    Value<String>? receiptSent,
    Value<int>? attempts,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? deletedAt,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      peerName: peerName ?? this.peerName,
      direction: direction ?? this.direction,
      kind: kind ?? this.kind,
      body: body ?? this.body,
      fileId: fileId ?? this.fileId,
      audience: audience ?? this.audience,
      senderId: senderId ?? this.senderId,
      replyToId: replyToId ?? this.replyToId,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      receiptSent: receiptSent ?? this.receiptSent,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (peerName.present) {
      map['peer_name'] = Variable<String>(peerName.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (audience.present) {
      map['audience'] = Variable<String>(audience.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(
        $MessagesTable.$convertersentAt.toSql(sentAt.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $MessagesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (receiptSent.present) {
      map['receipt_sent'] = Variable<String>(receiptSent.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<int>(
        $MessagesTable.$converterlastAttemptAtn.toSql(lastAttemptAt.value),
      );
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(
        $MessagesTable.$converterdeletedAtn.toSql(deletedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('peerName: $peerName, ')
          ..write('direction: $direction, ')
          ..write('kind: $kind, ')
          ..write('body: $body, ')
          ..write('fileId: $fileId, ')
          ..write('audience: $audience, ')
          ..write('senderId: $senderId, ')
          ..write('replyToId: $replyToId, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('receiptSent: $receiptSent, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $FilesTable extends Files with TableInfo<$FilesTable, FileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesTransferredMeta = const VerificationMeta(
    'bytesTransferred',
  );
  @override
  late final GeneratedColumn<int> bytesTransferred = GeneratedColumn<int>(
    'bytes_transferred',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> createdAt =
      GeneratedColumn<int>(
        'created_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FilesTable.$convertercreatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FilesTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileId,
    messageId,
    peerId,
    direction,
    name,
    mimeType,
    size,
    bytesTransferred,
    status,
    sha256,
    localPath,
    error,
    attempts,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'files';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('bytes_transferred')) {
      context.handle(
        _bytesTransferredMeta,
        bytesTransferred.isAcceptableOrUnknown(
          data['bytes_transferred']!,
          _bytesTransferredMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      bytesTransferred: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_transferred'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: $FilesTable.$convertercreatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}created_at'],
        )!,
      ),
      updatedAt: $FilesTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $FilesTable createAlias(String alias) {
    return $FilesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $convertercreatedAt = const UtcMicros();
  static TypeConverter<DateTime, int> $converterupdatedAt = const UtcMicros();
}

class FileRow extends DataClass implements Insertable<FileRow> {
  final int id;

  /// The ID on the wire; also the file's name on disk.
  final String fileId;

  /// The chat message that carries it.
  final String messageId;

  /// The other person's device ID.
  final String peerId;

  /// `in` or `out`.
  final String direction;

  /// Display name, already sanitised.
  final String name;
  final String mimeType;
  final int size;
  final int bytesTransferred;

  /// Transfer state: `preparing`, `offered`, `queued`, `inProgress`,
  /// `paused`, `completed`, `failed`, `cancelled` or `rejected`.
  final String status;

  /// Lowercase hex SHA-256; null while the sender is still hashing.
  final String? sha256;

  /// Where the bytes are, relative to the files directory; null when there
  /// is no copy on this phone (not received yet, or deleted).
  final String? localPath;

  /// Why it failed or was rejected (a fixed code).
  final String? error;

  /// Automatic resume attempts since the last success or manual retry.
  final int attempts;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FileRow({
    required this.id,
    required this.fileId,
    required this.messageId,
    required this.peerId,
    required this.direction,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.bytesTransferred,
    required this.status,
    this.sha256,
    this.localPath,
    this.error,
    required this.attempts,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_id'] = Variable<String>(fileId);
    map['message_id'] = Variable<String>(messageId);
    map['peer_id'] = Variable<String>(peerId);
    map['direction'] = Variable<String>(direction);
    map['name'] = Variable<String>(name);
    map['mime_type'] = Variable<String>(mimeType);
    map['size'] = Variable<int>(size);
    map['bytes_transferred'] = Variable<int>(bytesTransferred);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    map['attempts'] = Variable<int>(attempts);
    {
      map['created_at'] = Variable<int>(
        $FilesTable.$convertercreatedAt.toSql(createdAt),
      );
    }
    {
      map['updated_at'] = Variable<int>(
        $FilesTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  FilesCompanion toCompanion(bool nullToAbsent) {
    return FilesCompanion(
      id: Value(id),
      fileId: Value(fileId),
      messageId: Value(messageId),
      peerId: Value(peerId),
      direction: Value(direction),
      name: Value(name),
      mimeType: Value(mimeType),
      size: Value(size),
      bytesTransferred: Value(bytesTransferred),
      status: Value(status),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileRow(
      id: serializer.fromJson<int>(json['id']),
      fileId: serializer.fromJson<String>(json['fileId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      peerId: serializer.fromJson<String>(json['peerId']),
      direction: serializer.fromJson<String>(json['direction']),
      name: serializer.fromJson<String>(json['name']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      size: serializer.fromJson<int>(json['size']),
      bytesTransferred: serializer.fromJson<int>(json['bytesTransferred']),
      status: serializer.fromJson<String>(json['status']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      error: serializer.fromJson<String?>(json['error']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileId': serializer.toJson<String>(fileId),
      'messageId': serializer.toJson<String>(messageId),
      'peerId': serializer.toJson<String>(peerId),
      'direction': serializer.toJson<String>(direction),
      'name': serializer.toJson<String>(name),
      'mimeType': serializer.toJson<String>(mimeType),
      'size': serializer.toJson<int>(size),
      'bytesTransferred': serializer.toJson<int>(bytesTransferred),
      'status': serializer.toJson<String>(status),
      'sha256': serializer.toJson<String?>(sha256),
      'localPath': serializer.toJson<String?>(localPath),
      'error': serializer.toJson<String?>(error),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FileRow copyWith({
    int? id,
    String? fileId,
    String? messageId,
    String? peerId,
    String? direction,
    String? name,
    String? mimeType,
    int? size,
    int? bytesTransferred,
    String? status,
    Value<String?> sha256 = const Value.absent(),
    Value<String?> localPath = const Value.absent(),
    Value<String?> error = const Value.absent(),
    int? attempts,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FileRow(
    id: id ?? this.id,
    fileId: fileId ?? this.fileId,
    messageId: messageId ?? this.messageId,
    peerId: peerId ?? this.peerId,
    direction: direction ?? this.direction,
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    bytesTransferred: bytesTransferred ?? this.bytesTransferred,
    status: status ?? this.status,
    sha256: sha256.present ? sha256.value : this.sha256,
    localPath: localPath.present ? localPath.value : this.localPath,
    error: error.present ? error.value : this.error,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FileRow copyWithCompanion(FilesCompanion data) {
    return FileRow(
      id: data.id.present ? data.id.value : this.id,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      direction: data.direction.present ? data.direction.value : this.direction,
      name: data.name.present ? data.name.value : this.name,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      size: data.size.present ? data.size.value : this.size,
      bytesTransferred: data.bytesTransferred.present
          ? data.bytesTransferred.value
          : this.bytesTransferred,
      status: data.status.present ? data.status.value : this.status,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      error: data.error.present ? data.error.value : this.error,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileRow(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('bytesTransferred: $bytesTransferred, ')
          ..write('status: $status, ')
          ..write('sha256: $sha256, ')
          ..write('localPath: $localPath, ')
          ..write('error: $error, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileId,
    messageId,
    peerId,
    direction,
    name,
    mimeType,
    size,
    bytesTransferred,
    status,
    sha256,
    localPath,
    error,
    attempts,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileRow &&
          other.id == this.id &&
          other.fileId == this.fileId &&
          other.messageId == this.messageId &&
          other.peerId == this.peerId &&
          other.direction == this.direction &&
          other.name == this.name &&
          other.mimeType == this.mimeType &&
          other.size == this.size &&
          other.bytesTransferred == this.bytesTransferred &&
          other.status == this.status &&
          other.sha256 == this.sha256 &&
          other.localPath == this.localPath &&
          other.error == this.error &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FilesCompanion extends UpdateCompanion<FileRow> {
  final Value<int> id;
  final Value<String> fileId;
  final Value<String> messageId;
  final Value<String> peerId;
  final Value<String> direction;
  final Value<String> name;
  final Value<String> mimeType;
  final Value<int> size;
  final Value<int> bytesTransferred;
  final Value<String> status;
  final Value<String?> sha256;
  final Value<String?> localPath;
  final Value<String?> error;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const FilesCompanion({
    this.id = const Value.absent(),
    this.fileId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.peerId = const Value.absent(),
    this.direction = const Value.absent(),
    this.name = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.size = const Value.absent(),
    this.bytesTransferred = const Value.absent(),
    this.status = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.localPath = const Value.absent(),
    this.error = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  FilesCompanion.insert({
    this.id = const Value.absent(),
    required String fileId,
    required String messageId,
    required String peerId,
    required String direction,
    required String name,
    required String mimeType,
    required int size,
    this.bytesTransferred = const Value.absent(),
    required String status,
    this.sha256 = const Value.absent(),
    this.localPath = const Value.absent(),
    this.error = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : fileId = Value(fileId),
       messageId = Value(messageId),
       peerId = Value(peerId),
       direction = Value(direction),
       name = Value(name),
       mimeType = Value(mimeType),
       size = Value(size),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FileRow> custom({
    Expression<int>? id,
    Expression<String>? fileId,
    Expression<String>? messageId,
    Expression<String>? peerId,
    Expression<String>? direction,
    Expression<String>? name,
    Expression<String>? mimeType,
    Expression<int>? size,
    Expression<int>? bytesTransferred,
    Expression<String>? status,
    Expression<String>? sha256,
    Expression<String>? localPath,
    Expression<String>? error,
    Expression<int>? attempts,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileId != null) 'file_id': fileId,
      if (messageId != null) 'message_id': messageId,
      if (peerId != null) 'peer_id': peerId,
      if (direction != null) 'direction': direction,
      if (name != null) 'name': name,
      if (mimeType != null) 'mime_type': mimeType,
      if (size != null) 'size': size,
      if (bytesTransferred != null) 'bytes_transferred': bytesTransferred,
      if (status != null) 'status': status,
      if (sha256 != null) 'sha256': sha256,
      if (localPath != null) 'local_path': localPath,
      if (error != null) 'error': error,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  FilesCompanion copyWith({
    Value<int>? id,
    Value<String>? fileId,
    Value<String>? messageId,
    Value<String>? peerId,
    Value<String>? direction,
    Value<String>? name,
    Value<String>? mimeType,
    Value<int>? size,
    Value<int>? bytesTransferred,
    Value<String>? status,
    Value<String?>? sha256,
    Value<String?>? localPath,
    Value<String?>? error,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return FilesCompanion(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      messageId: messageId ?? this.messageId,
      peerId: peerId ?? this.peerId,
      direction: direction ?? this.direction,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      size: size ?? this.size,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      sha256: sha256 ?? this.sha256,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (bytesTransferred.present) {
      map['bytes_transferred'] = Variable<int>(bytesTransferred.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(
        $FilesTable.$convertercreatedAt.toSql(createdAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $FilesTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FilesCompanion(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('messageId: $messageId, ')
          ..write('peerId: $peerId, ')
          ..write('direction: $direction, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('size: $size, ')
          ..write('bytesTransferred: $bytesTransferred, ')
          ..write('status: $status, ')
          ..write('sha256: $sha256, ')
          ..write('localPath: $localPath, ')
          ..write('error: $error, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MessageRecipientsTable extends MessageRecipients
    with TableInfo<$MessageRecipientsTable, RecipientRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageRecipientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientIdMeta = const VerificationMeta(
    'recipientId',
  );
  @override
  late final GeneratedColumn<String> recipientId = GeneratedColumn<String>(
    'recipient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientNameMeta = const VerificationMeta(
    'recipientName',
  );
  @override
  late final GeneratedColumn<String> recipientName = GeneratedColumn<String>(
    'recipient_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($MessageRecipientsTable.$converterupdatedAt);
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    recipientId,
    recipientName,
    status,
    attempts,
    fileId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_recipients';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipientRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('recipient_id')) {
      context.handle(
        _recipientIdMeta,
        recipientId.isAcceptableOrUnknown(
          data['recipient_id']!,
          _recipientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientIdMeta);
    }
    if (data.containsKey('recipient_name')) {
      context.handle(
        _recipientNameMeta,
        recipientName.isAcceptableOrUnknown(
          data['recipient_name']!,
          _recipientNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientNameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, recipientId};
  @override
  RecipientRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipientRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      recipientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_id'],
      )!,
      recipientName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      ),
      updatedAt: $MessageRecipientsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
    );
  }

  @override
  $MessageRecipientsTable createAlias(String alias) {
    return $MessageRecipientsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const UtcMicros();
}

class RecipientRow extends DataClass implements Insertable<RecipientRow> {
  final String messageId;
  final String recipientId;
  final String recipientName;

  /// `pending`, `sending`, `sent`, `delivered`, `read` or `failed`.
  final String status;
  final int attempts;

  /// File messages: this recipient's own transfer in [Files].
  final String? fileId;
  final DateTime updatedAt;
  const RecipientRow({
    required this.messageId,
    required this.recipientId,
    required this.recipientName,
    required this.status,
    required this.attempts,
    this.fileId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['recipient_id'] = Variable<String>(recipientId);
    map['recipient_name'] = Variable<String>(recipientName);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || fileId != null) {
      map['file_id'] = Variable<String>(fileId);
    }
    {
      map['updated_at'] = Variable<int>(
        $MessageRecipientsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    return map;
  }

  MessageRecipientsCompanion toCompanion(bool nullToAbsent) {
    return MessageRecipientsCompanion(
      messageId: Value(messageId),
      recipientId: Value(recipientId),
      recipientName: Value(recipientName),
      status: Value(status),
      attempts: Value(attempts),
      fileId: fileId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileId),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecipientRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipientRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      recipientId: serializer.fromJson<String>(json['recipientId']),
      recipientName: serializer.fromJson<String>(json['recipientName']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      fileId: serializer.fromJson<String?>(json['fileId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'recipientId': serializer.toJson<String>(recipientId),
      'recipientName': serializer.toJson<String>(recipientName),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'fileId': serializer.toJson<String?>(fileId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecipientRow copyWith({
    String? messageId,
    String? recipientId,
    String? recipientName,
    String? status,
    int? attempts,
    Value<String?> fileId = const Value.absent(),
    DateTime? updatedAt,
  }) => RecipientRow(
    messageId: messageId ?? this.messageId,
    recipientId: recipientId ?? this.recipientId,
    recipientName: recipientName ?? this.recipientName,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    fileId: fileId.present ? fileId.value : this.fileId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecipientRow copyWithCompanion(MessageRecipientsCompanion data) {
    return RecipientRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      recipientId: data.recipientId.present
          ? data.recipientId.value
          : this.recipientId,
      recipientName: data.recipientName.present
          ? data.recipientName.value
          : this.recipientName,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipientRow(')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('recipientName: $recipientName, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('fileId: $fileId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    messageId,
    recipientId,
    recipientName,
    status,
    attempts,
    fileId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipientRow &&
          other.messageId == this.messageId &&
          other.recipientId == this.recipientId &&
          other.recipientName == this.recipientName &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.fileId == this.fileId &&
          other.updatedAt == this.updatedAt);
}

class MessageRecipientsCompanion extends UpdateCompanion<RecipientRow> {
  final Value<String> messageId;
  final Value<String> recipientId;
  final Value<String> recipientName;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> fileId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MessageRecipientsCompanion({
    this.messageId = const Value.absent(),
    this.recipientId = const Value.absent(),
    this.recipientName = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.fileId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageRecipientsCompanion.insert({
    required String messageId,
    required String recipientId,
    required String recipientName,
    required String status,
    this.attempts = const Value.absent(),
    this.fileId = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       recipientId = Value(recipientId),
       recipientName = Value(recipientName),
       status = Value(status),
       updatedAt = Value(updatedAt);
  static Insertable<RecipientRow> custom({
    Expression<String>? messageId,
    Expression<String>? recipientId,
    Expression<String>? recipientName,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? fileId,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (recipientId != null) 'recipient_id': recipientId,
      if (recipientName != null) 'recipient_name': recipientName,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (fileId != null) 'file_id': fileId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageRecipientsCompanion copyWith({
    Value<String>? messageId,
    Value<String>? recipientId,
    Value<String>? recipientName,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? fileId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MessageRecipientsCompanion(
      messageId: messageId ?? this.messageId,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      fileId: fileId ?? this.fileId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (recipientId.present) {
      map['recipient_id'] = Variable<String>(recipientId.value);
    }
    if (recipientName.present) {
      map['recipient_name'] = Variable<String>(recipientName.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $MessageRecipientsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageRecipientsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('recipientId: $recipientId, ')
          ..write('recipientName: $recipientName, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('fileId: $fileId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $FilesTable files = $FilesTable(this);
  late final $MessageRecipientsTable messageRecipients =
      $MessageRecipientsTable(this);
  late final Index messagesByChat = Index(
    'messages_by_chat',
    'CREATE INDEX messages_by_chat ON messages (conversation_id, created_at)',
  );
  late final Index messagesByStatus = Index(
    'messages_by_status',
    'CREATE INDEX messages_by_status ON messages (status)',
  );
  late final Index messagesUnread = Index(
    'messages_unread',
    'CREATE INDEX messages_unread ON messages (conversation_id, is_read)',
  );
  late final Index filesByContent = Index(
    'files_by_content',
    'CREATE INDEX files_by_content ON files (sha256, size)',
  );
  late final Index filesByStatus = Index(
    'files_by_status',
    'CREATE INDEX files_by_status ON files (status)',
  );
  late final Index filesByMessage = Index(
    'files_by_message',
    'CREATE INDEX files_by_message ON files (message_id)',
  );
  late final Index recipientsByDevice = Index(
    'recipients_by_device',
    'CREATE INDEX recipients_by_device ON message_recipients (recipient_id, status)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    files,
    messageRecipients,
    messagesByChat,
    messagesByStatus,
    messagesUnread,
    filesByContent,
    filesByStatus,
    filesByMessage,
    recipientsByDevice,
  ];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required String messageId,
  required String conversationId,
  required String peerName,
  required String direction,
  Value<String> kind,
  required String body,
  Value<String?> fileId,
  Value<String> audience,
  Value<String?> senderId,
  Value<String?> replyToId,
  required DateTime sentAt,
  required DateTime createdAt,
  required String status,
  Value<bool> isRead,
  Value<String> receiptSent,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> deletedAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<String> messageId,
  Value<String> conversationId,
  Value<String> peerName,
  Value<String> direction,
  Value<String> kind,
  Value<String> body,
  Value<String?> fileId,
  Value<String> audience,
  Value<String?> senderId,
  Value<String?> replyToId,
  Value<DateTime> sentAt,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<bool> isRead,
  Value<String> receiptSent,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> deletedAt,
});

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerName => $composableBuilder(
    column: $table.peerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audience => $composableBuilder(
    column: $table.audience,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get sentAt =>
      $composableBuilder(
        column: $table.sentAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receiptSent => $composableBuilder(
    column: $table.receiptSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastAttemptAt =>
      $composableBuilder(
        column: $table.lastAttemptAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get deletedAt =>
      $composableBuilder(
        column: $table.deletedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerName => $composableBuilder(
    column: $table.peerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audience => $composableBuilder(
    column: $table.audience,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRead => $composableBuilder(
    column: $table.isRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receiptSent => $composableBuilder(
    column: $table.receiptSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerName =>
      $composableBuilder(column: $table.peerName, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get audience =>
      $composableBuilder(column: $table.audience, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<String> get receiptSent => $composableBuilder(
    column: $table.receiptSent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastAttemptAt =>
      $composableBuilder(
        column: $table.lastAttemptAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> peerName = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> fileId = const Value.absent(),
                Value<String> audience = const Value.absent(),
                Value<String?> senderId = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String> receiptSent = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                peerName: peerName,
                direction: direction,
                kind: kind,
                body: body,
                fileId: fileId,
                audience: audience,
                senderId: senderId,
                replyToId: replyToId,
                sentAt: sentAt,
                createdAt: createdAt,
                status: status,
                isRead: isRead,
                receiptSent: receiptSent,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String messageId,
                required String conversationId,
                required String peerName,
                required String direction,
                Value<String> kind = const Value.absent(),
                required String body,
                Value<String?> fileId = const Value.absent(),
                Value<String> audience = const Value.absent(),
                Value<String?> senderId = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                required DateTime sentAt,
                required DateTime createdAt,
                required String status,
                Value<bool> isRead = const Value.absent(),
                Value<String> receiptSent = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                peerName: peerName,
                direction: direction,
                kind: kind,
                body: body,
                fileId: fileId,
                audience: audience,
                senderId: senderId,
                replyToId: replyToId,
                sentAt: sentAt,
                createdAt: createdAt,
                status: status,
                isRead: isRead,
                receiptSent: receiptSent,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTable, MessageRow>(table),
                  BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$FilesTableCreateCompanionBuilder = FilesCompanion Function({
  Value<int> id,
  required String fileId,
  required String messageId,
  required String peerId,
  required String direction,
  required String name,
  required String mimeType,
  required int size,
  Value<int> bytesTransferred,
  required String status,
  Value<String?> sha256,
  Value<String?> localPath,
  Value<String?> error,
  Value<int> attempts,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$FilesTableUpdateCompanionBuilder = FilesCompanion Function({
  Value<int> id,
  Value<String> fileId,
  Value<String> messageId,
  Value<String> peerId,
  Value<String> direction,
  Value<String> name,
  Value<String> mimeType,
  Value<int> size,
  Value<int> bytesTransferred,
  Value<String> status,
  Value<String?> sha256,
  Value<String?> localPath,
  Value<String?> error,
  Value<int> attempts,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

class $$FilesTableFilterComposer extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get createdAt =>
      $composableBuilder(
        column: $table.createdAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$FilesTableOrderingComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FilesTable> {
  $$FilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FilesTable,
          FileRow,
          $$FilesTableFilterComposer,
          $$FilesTableOrderingComposer,
          $$FilesTableAnnotationComposer,
          $$FilesTableCreateCompanionBuilder,
          $$FilesTableUpdateCompanionBuilder,
          (FileRow, BaseReferences<_$AppDatabase, $FilesTable, FileRow>),
          FileRow,
          PrefetchHooks Function()
        > {
  $$FilesTableTableManager(_$AppDatabase db, $FilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> bytesTransferred = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => FilesCompanion(
                id: id,
                fileId: fileId,
                messageId: messageId,
                peerId: peerId,
                direction: direction,
                name: name,
                mimeType: mimeType,
                size: size,
                bytesTransferred: bytesTransferred,
                status: status,
                sha256: sha256,
                localPath: localPath,
                error: error,
                attempts: attempts,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileId,
                required String messageId,
                required String peerId,
                required String direction,
                required String name,
                required String mimeType,
                required int size,
                Value<int> bytesTransferred = const Value.absent(),
                required String status,
                Value<String?> sha256 = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => FilesCompanion.insert(
                id: id,
                fileId: fileId,
                messageId: messageId,
                peerId: peerId,
                direction: direction,
                name: name,
                mimeType: mimeType,
                size: size,
                bytesTransferred: bytesTransferred,
                status: status,
                sha256: sha256,
                localPath: localPath,
                error: error,
                attempts: attempts,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FilesTable, FileRow>(table),
                  BaseReferences<_$AppDatabase, $FilesTable, FileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FilesTable,
      FileRow,
      $$FilesTableFilterComposer,
      $$FilesTableOrderingComposer,
      $$FilesTableAnnotationComposer,
      $$FilesTableCreateCompanionBuilder,
      $$FilesTableUpdateCompanionBuilder,
      (FileRow, BaseReferences<_$AppDatabase, $FilesTable, FileRow>),
      FileRow,
      PrefetchHooks Function()
    >;
typedef $$MessageRecipientsTableCreateCompanionBuilder =
    MessageRecipientsCompanion Function({
      required String messageId,
      required String recipientId,
      required String recipientName,
      required String status,
      Value<int> attempts,
      Value<String?> fileId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MessageRecipientsTableUpdateCompanionBuilder =
    MessageRecipientsCompanion Function({
      Value<String> messageId,
      Value<String> recipientId,
      Value<String> recipientName,
      Value<String> status,
      Value<int> attempts,
      Value<String?> fileId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MessageRecipientsTableFilterComposer
    extends Composer<_$AppDatabase, $MessageRecipientsTable> {
  $$MessageRecipientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientName => $composableBuilder(
    column: $table.recipientName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$MessageRecipientsTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageRecipientsTable> {
  $$MessageRecipientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientName => $composableBuilder(
    column: $table.recipientName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageRecipientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageRecipientsTable> {
  $$MessageRecipientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get recipientId => $composableBuilder(
    column: $table.recipientId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientName => $composableBuilder(
    column: $table.recipientName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MessageRecipientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageRecipientsTable,
          RecipientRow,
          $$MessageRecipientsTableFilterComposer,
          $$MessageRecipientsTableOrderingComposer,
          $$MessageRecipientsTableAnnotationComposer,
          $$MessageRecipientsTableCreateCompanionBuilder,
          $$MessageRecipientsTableUpdateCompanionBuilder,
          (
            RecipientRow,
            BaseReferences<
              _$AppDatabase,
              $MessageRecipientsTable,
              RecipientRow
            >,
          ),
          RecipientRow,
          PrefetchHooks Function()
        > {
  $$MessageRecipientsTableTableManager(
    _$AppDatabase db,
    $MessageRecipientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageRecipientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageRecipientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageRecipientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> recipientId = const Value.absent(),
                Value<String> recipientName = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> fileId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageRecipientsCompanion(
                messageId: messageId,
                recipientId: recipientId,
                recipientName: recipientName,
                status: status,
                attempts: attempts,
                fileId: fileId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String recipientId,
                required String recipientName,
                required String status,
                Value<int> attempts = const Value.absent(),
                Value<String?> fileId = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MessageRecipientsCompanion.insert(
                messageId: messageId,
                recipientId: recipientId,
                recipientName: recipientName,
                status: status,
                attempts: attempts,
                fileId: fileId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessageRecipientsTable, RecipientRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MessageRecipientsTable,
                    RecipientRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageRecipientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageRecipientsTable,
      RecipientRow,
      $$MessageRecipientsTableFilterComposer,
      $$MessageRecipientsTableOrderingComposer,
      $$MessageRecipientsTableAnnotationComposer,
      $$MessageRecipientsTableCreateCompanionBuilder,
      $$MessageRecipientsTableUpdateCompanionBuilder,
      (
        RecipientRow,
        BaseReferences<_$AppDatabase, $MessageRecipientsTable, RecipientRow>,
      ),
      RecipientRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$FilesTableTableManager get files =>
      $$FilesTableTableManager(_db, _db.files);
  $$MessageRecipientsTableTableManager get messageRecipients =>
      $$MessageRecipientsTableTableManager(_db, _db.messageRecipients);
}
