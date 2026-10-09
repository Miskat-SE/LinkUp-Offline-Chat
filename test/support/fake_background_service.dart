import 'package:resqmesh/core/platform/background.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Records what the background service would show.
final class FakeBackgroundService implements BackgroundService {
  final List<BackgroundState> states = [];
  int batterySettingsOpened = 0;

  BackgroundState? get last => states.isEmpty ? null : states.last;

  /// Whether the service would be running now.
  bool get running =>
      last != null && (last!.transferring || last!.stayReachable);

  @override
  Future<void> update(BackgroundState state) async => states.add(state);

  @override
  Future<void> openBatterySettings() async => batterySettingsOpened++;
}
