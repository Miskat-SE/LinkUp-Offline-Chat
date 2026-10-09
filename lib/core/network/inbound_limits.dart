import 'dart:collection';

import 'package:clock/clock.dart';

/// At most [limit] events per [window] for each key, such as a source IP
/// (PROJECT_PLAN.md §9, P9.3).
final class RateLimiter {
  RateLimiter({required this.limit, required this.window});

  final int limit;
  final Duration window;
  final Map<String, Queue<DateTime>> _events = {};

  /// Records an event for [key]; false if that would exceed the limit.
  bool allow(String key) {
    final now = clock.now();
    final cutoff = now.subtract(window);
    final events = _events.putIfAbsent(key, Queue.new);
    while (events.isNotEmpty && events.first.isBefore(cutoff)) {
      events.removeFirst();
    }
    if (events.length >= limit) return false;
    events.add(now);
    // Forget quiet keys so the map can't grow without bound.
    if (_events.length > 256) {
      _events.removeWhere((_, e) => e.isEmpty || e.last.isBefore(cutoff));
    }
    return true;
  }
}

/// Allows bursts up to [capacity], refilled at [perSecond].
final class TokenBucket {
  TokenBucket({required this.capacity, required this.perSecond})
    : _tokens = capacity.toDouble(),
      _last = clock.now();

  final int capacity;
  final double perSecond;
  double _tokens;
  DateTime _last;

  bool take() {
    final now = clock.now();
    final elapsed = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    _tokens = (_tokens + elapsed * perSecond).clamp(0, capacity.toDouble());
    if (_tokens < 1) return false;
    _tokens -= 1;
    return true;
  }
}
