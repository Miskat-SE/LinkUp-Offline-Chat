import 'package:drift/drift.dart';
import 'package:resqmesh/core/storage/app_database.dart';
import 'package:resqmesh/core/storage/file_store.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';

/// What is stored on this phone (PROJECT_PLAN.md §8.3).
final class StorageUsage {
  const StorageUsage({
    required this.messages,
    required this.received,
    required this.sent,
    required this.cacheBytes,
  });

  final int messages;
  final ({int files, int bytes}) received;

  /// Copies of sent files, kept so they can be resent or resumed.
  final ({int files, int bytes}) sent;

  /// Unfinished downloads and thumbnails.
  final int cacheBytes;

  int get totalBytes => received.bytes + sent.bytes + cacheBytes;
}

/// Whole-database and whole-folder actions for the Storage screen.
/// Running transfers must be stopped first (the transfer service does
/// that); screens watching the database update by themselves.
final class StorageManager {
  StorageManager(this._db, this._files);

  final AppDatabase _db;
  final FileStore _files;

  Stream<int> watchMessageCount() {
    final count = _db.messages.id.count();
    return (_db.selectOnly(
      _db.messages,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<StorageUsage> usage() async {
    final count = _db.messages.id.count();
    final messages = await (_db.selectOnly(
      _db.messages,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).getSingle();
    final partial = await _files.usage(FileStore.partialDir);
    final thumbs = await _files.usage(FileStore.thumbsDir);
    return StorageUsage(
      messages: messages,
      received: await _files.usage(FileStore.receivedDir),
      sent: await _files.usage(FileStore.sentDir),
      cacheBytes: partial.bytes + thumbs.bytes,
    );
  }

  /// Deletes every message and shared file on this phone, including ones
  /// still waiting to be sent. Other people's copies are not affected.
  /// Returns how many messages were deleted.
  Future<int> clearChatHistory() async {
    final deleted = await _db.transaction(() async {
      await _db.delete(_db.files).go();
      return _db.delete(_db.messages).go();
    });
    for (final dir in [
      FileStore.receivedDir,
      FileStore.partialDir,
      FileStore.sentDir,
      FileStore.thumbsDir,
    ]) {
      await _files.clear(dir);
    }
    return deleted;
  }

  /// Chats, files and identity: the app starts again at onboarding with a
  /// new device ID.
  Future<void> clearAllLocalData(KeyValueStore store) async {
    await clearChatHistory();
    for (final key in StoreKeys.all) {
      await store.remove(key);
    }
  }
}
