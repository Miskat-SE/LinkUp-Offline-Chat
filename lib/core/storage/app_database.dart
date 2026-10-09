import 'package:drift/drift.dart';

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
  TextColumn get body => text()();
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
@DriftDatabase(tables: [Messages])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
