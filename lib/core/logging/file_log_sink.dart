import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:resqmesh/core/logging/app_logger.dart';

/// Appends log lines to `resqmesh.log` in [directory], batching writes and
/// rotating to `resqmesh.1.log` once the file passes [maxBytes].
///
/// At most two files exist, so logs never use more than about 2 × [maxBytes].
final class FileLogSink implements LogSink {
  FileLogSink(
    this.directory, {
    this.maxBytes = 1024 * 1024,
    this.flushDelay = const Duration(seconds: 1),
  });

  final Directory directory;
  final int maxBytes;
  final Duration flushDelay;

  final List<String> _pending = [];
  Timer? _timer;
  Future<void> _writing = Future.value();

  File get currentFile => File(p.join(directory.path, 'resqmesh.log'));

  File get previousFile => File(p.join(directory.path, 'resqmesh.1.log'));

  @override
  void write(LogEntry entry) {
    _pending.add(entry.format());
    _timer ??= Timer(flushDelay, () => unawaited(flush()));
  }

  @override
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return _writing;
    final chunk = '${_pending.join('\n')}\n';
    _pending.clear();
    return _writing = _writing.then((_) => _append(chunk));
  }

  Future<void> _append(String chunk) async {
    try {
      await directory.create(recursive: true);
      final file = currentFile;
      await file.writeAsString(chunk, mode: FileMode.append);
      if (file.lengthSync() > maxBytes) {
        if (previousFile.existsSync()) await previousFile.delete();
        await file.rename(previousFile.path);
      }
    } on FileSystemException {
      // Logging must never take the app down; drop this chunk.
    }
  }
}
