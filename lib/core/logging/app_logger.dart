import 'dart:async';
import 'dart:collection';

import 'package:clock/clock.dart';

/// Area of the app a log line belongs to (spec §35).
enum LogTag {
  app,
  discovery,
  network,
  message,
  file,
  db,
  service;

  String get label => name.toUpperCase();
}

enum LogLevel {
  debug('D'),
  info('I'),
  warning('W'),
  error('E');

  const LogLevel(this.letter);

  final String letter;
}

/// One structured log line.
///
/// Callers must never put message text or file names into [message] or
/// [fields]; use IDs and sizes instead.
final class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.fields = const {},
  });

  final DateTime time;
  final LogLevel level;
  final LogTag tag;
  final String message;
  final Map<String, Object?> fields;

  /// `2026-10-08T20:42:13.512 I [DISCOVERY] Peer found device=3f2a`
  String format() {
    final buffer = StringBuffer()
      ..write(_timestamp(time))
      ..write(' ')
      ..write(level.letter)
      ..write(' [')
      ..write(tag.label)
      ..write('] ')
      ..write(message);
    fields.forEach((key, value) {
      buffer
        ..write(' ')
        ..write(key)
        ..write('=')
        ..write(value);
    });
    return buffer.toString();
  }

  static String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}T'
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms';
  }
}

/// Destination for log entries. Sinks must never throw.
abstract interface class LogSink {
  void write(LogEntry entry);

  Future<void> flush();
}

/// Structured local logger: keeps the most recent entries in memory for the
/// developer screen and forwards every entry to its sinks.
final class AppLogger {
  AppLogger({
    this.capacity = 2000,
    this.minLevel = LogLevel.info,
    Iterable<LogSink> sinks = const [],
  }) : _sinks = [...sinks];

  /// Number of entries kept in memory.
  final int capacity;

  /// Entries below this level are dropped.
  final LogLevel minLevel;

  final List<LogSink> _sinks;
  final Queue<LogEntry> _recent = Queue<LogEntry>();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  /// The most recent entries, oldest first.
  List<LogEntry> get recent => List.unmodifiable(_recent);

  /// Every entry as it is logged.
  Stream<LogEntry> get entries => _controller.stream;

  void addSink(LogSink sink) => _sinks.add(sink);

  /// Whether a sink of type [S] is attached.
  bool hasSink<S extends LogSink>() => _sinks.any((sink) => sink is S);

  void debug(LogTag tag, String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.debug, tag, message, fields);

  void info(LogTag tag, String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.info, tag, message, fields);

  void warning(LogTag tag, String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.warning, tag, message, fields);

  void error(LogTag tag, String message, [Map<String, Object?>? fields]) =>
      log(LogLevel.error, tag, message, fields);

  void log(
    LogLevel level,
    LogTag tag,
    String message, [
    Map<String, Object?>? fields,
  ]) {
    if (level.index < minLevel.index) return;
    final entry = LogEntry(
      time: clock.now(),
      level: level,
      tag: tag,
      message: message,
      fields: fields ?? const {},
    );
    _recent.addLast(entry);
    while (_recent.length > capacity) {
      _recent.removeFirst();
    }
    for (final sink in _sinks) {
      sink.write(entry);
    }
    if (!_controller.isClosed) _controller.add(entry);
  }

  Future<void> flush() async {
    for (final sink in _sinks) {
      await sink.flush();
    }
  }

  Future<void> dispose() async {
    await flush();
    await _controller.close();
  }
}
