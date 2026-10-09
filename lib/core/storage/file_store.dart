import 'dart:io';

import 'package:path/path.dart' as p;

/// Where shared files live in app-internal storage (PROJECT_PLAN.md §8.2).
/// Every file is stored under its `fileId`, never under a received name
/// (ADR-0014). Paths in the database are relative to [root].
///
/// ```
/// <root>/received/<fileId>      completed incoming files
/// <root>/partial/<fileId>.part  incoming files in progress or paused
/// <root>/sent/<fileId>          stable copies of files being sent
/// <root>/thumbs/<fileId>.jpg    image and video thumbnails
/// ```
final class FileStore {
  FileStore(this.root);

  final Directory root;

  static const receivedDir = 'received';
  static const partialDir = 'partial';
  static const sentDir = 'sent';
  static const thumbsDir = 'thumbs';

  static String receivedPath(String fileId) => p.join(receivedDir, fileId);
  static String partialPath(String fileId) =>
      p.join(partialDir, '$fileId.part');
  static String sentPath(String fileId) => p.join(sentDir, fileId);
  static String thumbPath(String fileId) => p.join(thumbsDir, '$fileId.jpg');

  /// The absolute path of a path stored in the database.
  String absolute(String relativePath) => p.join(root.path, relativePath);

  File file(String relativePath) => File(absolute(relativePath));

  Future<void> ensureDirectories() async {
    for (final dir in [receivedDir, partialDir, sentDir, thumbsDir]) {
      await Directory(p.join(root.path, dir)).create(recursive: true);
    }
  }

  /// Bytes and file count in one of the directories above.
  Future<({int files, int bytes})> usage(String dir) async {
    final directory = Directory(p.join(root.path, dir));
    var files = 0;
    var bytes = 0;
    if (!directory.existsSync()) return (files: 0, bytes: 0);
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      files++;
      bytes += await entry.length();
    }
    return (files: files, bytes: bytes);
  }

  /// Deletes a stored file if it exists.
  Future<void> delete(String relativePath) async {
    final target = file(relativePath);
    if (target.existsSync()) await target.delete();
  }

  /// Deletes every file in [dir] except those in [keep] (relative paths).
  Future<int> clear(String dir, {Set<String> keep = const {}}) async {
    final directory = Directory(p.join(root.path, dir));
    if (!directory.existsSync()) return 0;
    var deleted = 0;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File) continue;
      if (keep.contains(p.relative(entry.path, from: root.path))) continue;
      await entry.delete();
      deleted++;
    }
    return deleted;
  }
}
