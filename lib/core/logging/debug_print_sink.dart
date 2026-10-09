import 'package:flutter/foundation.dart';
import 'package:resqmesh/core/logging/app_logger.dart';

/// Mirrors log lines to the debug console. Added in debug builds only.
final class DebugPrintSink implements LogSink {
  const DebugPrintSink();

  @override
  void write(LogEntry entry) => debugPrint(entry.format());

  @override
  Future<void> flush() async {}
}
