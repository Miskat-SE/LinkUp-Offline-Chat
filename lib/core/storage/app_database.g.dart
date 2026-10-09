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
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [
    id,
    messageId,
    conversationId,
    peerName,
    direction,
    body,
    replyToId,
    sentAt,
    createdAt,
    status,
    isRead,
    receiptSent,
    attempts,
    lastAttemptAt,
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
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
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
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
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
  final String body;
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
  const MessageRow({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.peerName,
    required this.direction,
    required this.body,
    this.replyToId,
    required this.sentAt,
    required this.createdAt,
    required this.status,
    required this.isRead,
    required this.receiptSent,
    required this.attempts,
    this.lastAttemptAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['peer_name'] = Variable<String>(peerName);
    map['direction'] = Variable<String>(direction);
    map['body'] = Variable<String>(body);
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
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      peerName: Value(peerName),
      direction: Value(direction),
      body: Value(body),
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
      body: serializer.fromJson<String>(json['body']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      sentAt: serializer.fromJson<DateTime>(json['sentAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      status: serializer.fromJson<String>(json['status']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      receiptSent: serializer.fromJson<String>(json['receiptSent']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
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
      'body': serializer.toJson<String>(body),
      'replyToId': serializer.toJson<String?>(replyToId),
      'sentAt': serializer.toJson<DateTime>(sentAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'status': serializer.toJson<String>(status),
      'isRead': serializer.toJson<bool>(isRead),
      'receiptSent': serializer.toJson<String>(receiptSent),
      'attempts': serializer.toJson<int>(attempts),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  MessageRow copyWith({
    int? id,
    String? messageId,
    String? conversationId,
    String? peerName,
    String? direction,
    String? body,
    Value<String?> replyToId = const Value.absent(),
    DateTime? sentAt,
    DateTime? createdAt,
    String? status,
    bool? isRead,
    String? receiptSent,
    int? attempts,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
  }) => MessageRow(
    id: id ?? this.id,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    peerName: peerName ?? this.peerName,
    direction: direction ?? this.direction,
    body: body ?? this.body,
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
      body: data.body.present ? data.body.value : this.body,
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
          ..write('body: $body, ')
          ..write('replyToId: $replyToId, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('receiptSent: $receiptSent, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt')
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
    body,
    replyToId,
    sentAt,
    createdAt,
    status,
    isRead,
    receiptSent,
    attempts,
    lastAttemptAt,
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
          other.body == this.body &&
          other.replyToId == this.replyToId &&
          other.sentAt == this.sentAt &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.isRead == this.isRead &&
          other.receiptSent == this.receiptSent &&
          other.attempts == this.attempts &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<int> id;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> peerName;
  final Value<String> direction;
  final Value<String> body;
  final Value<String?> replyToId;
  final Value<DateTime> sentAt;
  final Value<DateTime> createdAt;
  final Value<String> status;
  final Value<bool> isRead;
  final Value<String> receiptSent;
  final Value<int> attempts;
  final Value<DateTime?> lastAttemptAt;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.peerName = const Value.absent(),
    this.direction = const Value.absent(),
    this.body = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.isRead = const Value.absent(),
    this.receiptSent = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required String messageId,
    required String conversationId,
    required String peerName,
    required String direction,
    required String body,
    this.replyToId = const Value.absent(),
    required DateTime sentAt,
    required DateTime createdAt,
    required String status,
    this.isRead = const Value.absent(),
    this.receiptSent = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
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
    Expression<String>? body,
    Expression<String>? replyToId,
    Expression<int>? sentAt,
    Expression<int>? createdAt,
    Expression<String>? status,
    Expression<bool>? isRead,
    Expression<String>? receiptSent,
    Expression<int>? attempts,
    Expression<int>? lastAttemptAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (peerName != null) 'peer_name': peerName,
      if (direction != null) 'direction': direction,
      if (body != null) 'body': body,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (sentAt != null) 'sent_at': sentAt,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (isRead != null) 'is_read': isRead,
      if (receiptSent != null) 'receipt_sent': receiptSent,
      if (attempts != null) 'attempts': attempts,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? peerName,
    Value<String>? direction,
    Value<String>? body,
    Value<String?>? replyToId,
    Value<DateTime>? sentAt,
    Value<DateTime>? createdAt,
    Value<String>? status,
    Value<bool>? isRead,
    Value<String>? receiptSent,
    Value<int>? attempts,
    Value<DateTime?>? lastAttemptAt,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      peerName: peerName ?? this.peerName,
      direction: direction ?? this.direction,
      body: body ?? this.body,
      replyToId: replyToId ?? this.replyToId,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      receiptSent: receiptSent ?? this.receiptSent,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
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
    if (body.present) {
      map['body'] = Variable<String>(body.value);
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
          ..write('body: $body, ')
          ..write('replyToId: $replyToId, ')
          ..write('sentAt: $sentAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('receiptSent: $receiptSent, ')
          ..write('attempts: $attempts, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MessagesTable messages = $MessagesTable(this);
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    messages,
    messagesByChat,
    messagesByStatus,
    messagesUnread,
  ];
}

typedef $$MessagesTableCreateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  required String messageId,
  required String conversationId,
  required String peerName,
  required String direction,
  required String body,
  Value<String?> replyToId,
  required DateTime sentAt,
  required DateTime createdAt,
  required String status,
  Value<bool> isRead,
  Value<String> receiptSent,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
});
typedef $$MessagesTableUpdateCompanionBuilder = MessagesCompanion Function({
  Value<int> id,
  Value<String> messageId,
  Value<String> conversationId,
  Value<String> peerName,
  Value<String> direction,
  Value<String> body,
  Value<String?> replyToId,
  Value<DateTime> sentAt,
  Value<DateTime> createdAt,
  Value<String> status,
  Value<bool> isRead,
  Value<String> receiptSent,
  Value<int> attempts,
  Value<DateTime?> lastAttemptAt,
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

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
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

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
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

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

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
                Value<String> body = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<DateTime> sentAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isRead = const Value.absent(),
                Value<String> receiptSent = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                peerName: peerName,
                direction: direction,
                body: body,
                replyToId: replyToId,
                sentAt: sentAt,
                createdAt: createdAt,
                status: status,
                isRead: isRead,
                receiptSent: receiptSent,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String messageId,
                required String conversationId,
                required String peerName,
                required String direction,
                required String body,
                Value<String?> replyToId = const Value.absent(),
                required DateTime sentAt,
                required DateTime createdAt,
                required String status,
                Value<bool> isRead = const Value.absent(),
                Value<String> receiptSent = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                messageId: messageId,
                conversationId: conversationId,
                peerName: peerName,
                direction: direction,
                body: body,
                replyToId: replyToId,
                sentAt: sentAt,
                createdAt: createdAt,
                status: status,
                isRead: isRead,
                receiptSent: receiptSent,
                attempts: attempts,
                lastAttemptAt: lastAttemptAt,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
}
