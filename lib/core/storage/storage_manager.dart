import 'package:drift/drift.dart';
import 'package:resqmesh/core/storage/app_database.dart';

/// Whole-database actions for the Storage screen (PROJECT_PLAN.md §8.3).
/// Screens watching the database update by themselves afterwards.
final class StorageManager {
  StorageManager(this._db);

  final AppDatabase _db;

  Stream<int> watchMessageCount() {
    final count = _db.messages.id.count();
    return (_db.selectOnly(
      _db.messages,
    )..addColumns([count])).map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Deletes every message on this phone, including ones still waiting to
  /// be sent. Other people's copies are not affected. Returns how many.
  Future<int> clearChatHistory() => _db.delete(_db.messages).go();
}
