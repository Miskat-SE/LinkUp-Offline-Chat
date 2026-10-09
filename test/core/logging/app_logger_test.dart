import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/logging/app_logger.dart';
import 'package:resqmesh/core/logging/file_log_sink.dart';

final class _ListSink implements LogSink {
  final lines = <String>[];

  @override
  void write(LogEntry entry) => lines.add(entry.format());

  @override
  Future<void> flush() async {}
}

void main() {
  group('LogEntry.format', () {
    test('writes time, level, tag, message and fields', () {
      final entry = LogEntry(
        time: DateTime(2026, 10, 8, 20, 42, 13, 512),
        level: LogLevel.info,
        tag: LogTag.discovery,
        message: 'Peer found',
        fields: const {'device': '3f2a'},
      );
      expect(
        entry.format(),
        '2026-10-08T20:42:13.512 I [DISCOVERY] Peer found device=3f2a',
      );
    });
  });

  group('AppLogger', () {
    test('drops entries below the minimum level', () {
      final sink = _ListSink();
      AppLogger(sinks: [sink])
        ..debug(LogTag.app, 'hidden')
        ..info(LogTag.app, 'shown');
      expect(sink.lines, hasLength(1));
      expect(sink.lines.single, contains('shown'));
    });

    test('keeps only the most recent entries in memory', () {
      final logger = AppLogger(capacity: 3);
      for (var i = 0; i < 5; i++) {
        logger.info(LogTag.app, 'entry $i');
      }
      expect(logger.recent.map((e) => e.message), [
        'entry 2',
        'entry 3',
        'entry 4',
      ]);
    });

    test('streams entries and stamps them with the injected clock', () async {
      final logger = AppLogger();
      final time = DateTime(2026, 10, 8, 9);
      final next = logger.entries.first;
      withClock(Clock.fixed(time), () => logger.warning(LogTag.network, 'x'));
      final entry = await next;
      expect(entry.time, time);
      expect(entry.level, LogLevel.warning);
      await logger.dispose();
    });

    test('reports which sinks are attached', () {
      final logger = AppLogger(sinks: [_ListSink()]);
      expect(logger.hasSink<_ListSink>(), isTrue);
      expect(logger.hasSink<FileLogSink>(), isFalse);
    });
  });

  group('FileLogSink', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('logs'));
    tearDown(() async => dir.delete(recursive: true));

    LogEntry entry(String message) => LogEntry(
      time: DateTime(2026),
      level: LogLevel.info,
      tag: LogTag.app,
      message: message,
    );

    test('appends lines when flushed', () async {
      final sink = FileLogSink(dir)
        ..write(entry('one'))
        ..write(entry('two'));
      await sink.flush();
      final lines = await sink.currentFile.readAsLines();
      expect(lines, hasLength(2));
      expect(lines.last, endsWith('two'));
    });

    test(
      'rotates to a single previous file once the limit is passed',
      () async {
        final sink = FileLogSink(dir, maxBytes: 200);
        for (var round = 0; round < 3; round++) {
          for (var i = 0; i < 5; i++) {
            sink.write(entry('round $round line $i'));
          }
          await sink.flush();
        }
        expect(sink.previousFile.existsSync(), isTrue);
        final files = dir.listSync().whereType<File>().toList();
        expect(files, hasLength(lessThanOrEqualTo(2)));
      },
    );
  });
}
