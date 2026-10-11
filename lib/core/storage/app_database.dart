import 'package:drift/drift.dart';
import 'package:resqmesh/core/storage/app_database.steps.dart';

part 'app_database.g.dart';

/// Chat messages (PROJECT_PLAN.md §8.1). Stored values are plain text codes
/// so the schema doesn't depend on Dart enum names; the chat feature's
/// repository maps them.
@DataClassName('MessageRow')
@TableIndex(name: 'messages_by_chat', columns: {#conversationId, #createdAt})
@TableIndex(name: 'messages_by_status', columns: {#status})
@TableIndex(name: 'messages_unread', columns: {#conversationId, #isRead})
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The ID on the wire; the same on both phones.
  TextColumn get messageId => text().unique()();

  /// The other person's device ID.
  TextColumn get conversationId => text()();

  /// Their name when the message was sent or received.
  TextColumn get peerName => text()();

  /// `in` or `out`.
  TextColumn get direction => text()();

  /// `text` or `file` (schema v2).
  TextColumn get kind => text().withDefault(const Constant('text'))();

  /// The text; empty for a file message.
  TextColumn get body => text()();

  /// File messages only: the row in [Files] (schema v2).
  TextColumn get fileId => text().nullable()();

  /// `direct` or `everyone` (schema v3).
  TextColumn get audience => text().withDefault(const Constant('direct'))();

  /// Incoming Everyone messages: the sender's device ID (schema v3).
  TextColumn get senderId => text().nullable()();
  TextColumn get replyToId => text().nullable()();

  /// The sender's clock; shown, never used for ordering.
  IntColumn get sentAt => integer().map(const UtcMicros())();

  /// This phone's clock; chats are ordered by it.
  IntColumn get createdAt => integer().map(const UtcMicros())();

  /// `pending`, `sending`, `sent`, `delivered`, `read`, `failed` or
  /// `received` (§7.4).
  TextColumn get status => text()();

  /// Incoming only: the chat was opened since it arrived.
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  /// Incoming only: the last receipt sent back, `none`, `delivered` or
  /// `read`. Receipts that couldn't be sent go out on reconnect.
  TextColumn get receiptSent => text().withDefault(const Constant('none'))();

  /// Outgoing only: send attempts on the current connection.
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get lastAttemptAt => integer().map(const UtcMicros()).nullable()();

  /// Deleted for everyone (P15.4, schema v4): the text is wiped and the
  /// bubble says so. Outgoing ones are re-announced to recipients who come
  /// back within a week.
  IntColumn get deletedAt => integer().map(const UtcMicros()).nullable()();

  /// Everyone messages: device IDs @mentioned, comma-separated (P15.5,
  /// schema v4).
  TextColumn get mentions => text().nullable()();
}

/// Who an outgoing Everyone message went to, each with their own status
/// (PROJECT_PLAN.md §7.4, schema v3).
@DataClassName('RecipientRow')
@TableIndex(name: 'recipients_by_device', columns: {#recipientId, #status})
class MessageRecipients extends Table {
  TextColumn get messageId => text()();
  TextColumn get recipientId => text()();
  TextColumn get recipientName => text()();

  /// `pending`, `sending`, `sent`, `delivered`, `read` or `failed`.
  TextColumn get status => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// File messages: this recipient's own transfer in [Files].
  TextColumn get fileId => text().nullable()();
  IntColumn get updatedAt => integer().map(const UtcMicros())();

  @override
  Set<Column<Object>> get primaryKey => {messageId, recipientId};
}

/// Shared files and their transfer state (PROJECT_PLAN.md §8.1, schema v2).
/// The contents live on disk (FileStore); never in SQLite.
@DataClassName('FileRow')
@TableIndex(name: 'files_by_content', columns: {#sha256, #size})
@TableIndex(name: 'files_by_status', columns: {#status})
@TableIndex(name: 'files_by_message', columns: {#messageId})
class Files extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The ID on the wire; also the file's name on disk.
  TextColumn get fileId => text().unique()();

  /// The chat message that carries it.
  TextColumn get messageId => text()();

  /// The other person's device ID.
  TextColumn get peerId => text()();

  /// `in` or `out`.
  TextColumn get direction => text()();

  /// Display name, already sanitised.
  TextColumn get name => text()();
  TextColumn get mimeType => text()();
  IntColumn get size => integer()();
  IntColumn get bytesTransferred => integer().withDefault(const Constant(0))();

  /// Transfer state: `preparing`, `offered`, `queued`, `inProgress`,
  /// `paused`, `completed`, `failed`, `cancelled` or `rejected`.
  TextColumn get status => text()();

  /// Lowercase hex SHA-256; null while the sender is still hashing.
  TextColumn get sha256 => text().nullable()();

  /// Where the bytes are, relative to the files directory; null when there
  /// is no copy on this phone (not received yet, or deleted).
  TextColumn get localPath => text().nullable()();

  /// Why it failed or was rejected (a fixed code).
  TextColumn get error => text().nullable()();

  /// Automatic resume attempts since the last success or manual retry.
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().map(const UtcMicros())();
  IntColumn get updatedAt => integer().map(const UtcMicros())();
}

/// Times are stored as UTC microseconds: exact, and they sort correctly.
final class UtcMicros extends TypeConverter<DateTime, int> {
  const UtcMicros();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMicrosecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.toUtc().microsecondsSinceEpoch;
}

/// The app's SQLite database. Every schema change needs a new
/// [schemaVersion], a migration step and a schema snapshot
/// (`dart run drift_dev make-migrations`; see TESTING.md).
@DriftDatabase(tables: [Messages, Files, MessageRecipients])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2 (P6): file messages and the files table.
      from1To2: (m, schema) async {
        await m.addColumn(schema.messages, schema.messages.kind);
        await m.addColumn(schema.messages, schema.messages.fileId);
        await m.createTable(schema.files);
        for (final index in [
          schema.filesByContent,
          schema.filesByStatus,
          schema.filesByMessage,
        ]) {
          await m.createIndex(index);
        }
      },
      // v3 (P7): Everyone messages and their recipients.
      from2To3: (m, schema) async {
        await m.addColumn(schema.messages, schema.messages.audience);
        await m.addColumn(schema.messages, schema.messages.senderId);
        await m.createTable(schema.messageRecipients);
        await m.createIndex(schema.recipientsByDevice);
      },
      // v4 (P15.4–P15.5): delete for everyone, @mentions.
      from3To4: (m, schema) async {
        await m.addColumn(schema.messages, schema.messages.deletedAt);
        await m.addColumn(schema.messages, schema.messages.mentions);
      },
    ),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
