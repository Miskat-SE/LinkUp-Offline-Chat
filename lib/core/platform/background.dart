import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// The Android foreground service that keeps LinkUp working with its screen
/// closed (PROJECT_PLAN.md §5.6). Tests replace it.
abstract interface class BackgroundService {
  /// Runs the service while [BackgroundState.transferring] or
  /// [BackgroundState.stayReachable], with the given notification.
  Future<void> update(BackgroundState state);

  Future<void> openBatterySettings();
}

final class PlatformBackgroundService implements BackgroundService {
  PlatformBackgroundService([BackgroundHostApi? api])
    : _api = api ?? BackgroundHostApi();

  final BackgroundHostApi _api;

  @override
  Future<void> update(BackgroundState state) async {
    try {
      await _api.update(state);
    } on PlatformException {
      // Not allowed right now (app not visible); the next update retries.
    }
  }

  @override
  Future<void> openBatterySettings() => _api.openBatterySettings();
}

final backgroundServiceProvider = Provider<BackgroundService>(
  (ref) => PlatformBackgroundService(),
);
