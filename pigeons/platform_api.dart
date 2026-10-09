// Interface between Dart and the Kotlin platform bridge (ADR-0008).
//
// Regenerate after editing:
//   dart run pigeon --input pigeons/platform_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/platform/platform_api.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/app/src/main/kotlin/com/resqmesh/resqmesh/bridge/PlatformApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.resqmesh.resqmesh.bridge'),
  ),
)
/// One IPv4 address on a local network interface.
class LanInterfaceInfo {
  LanInterfaceInfo({
    required this.name,
    required this.address,
    required this.prefixLength,
    required this.kind,
  });

  /// Interface name, e.g. `wlan0`, `ap0`.
  String name;

  /// Dotted IPv4 address.
  String address;

  int prefixLength;

  /// `wifi` (joined a Wi-Fi network), `hotspot` (this phone is the access
  /// point) or `other` (e.g. Ethernet).
  String kind;
}

/// The phone's local networks at one moment.
class LanSnapshot {
  LanSnapshot({
    required this.wifiConnected,
    required this.boundToWifi,
    required this.interfaces,
  });

  /// Joined a Wi-Fi network (with or without internet).
  bool wifiConnected;

  /// The process is bound to that Wi-Fi network (ADR-0007).
  bool boundToWifi;

  List<LanInterfaceInfo> interfaces;
}

class AppInfo {
  AppInfo({required this.versionName, required this.versionCode});

  String versionName;
  int versionCode;
}

@HostApi()
abstract class LanHostApi {
  /// Starts watching Wi-Fi and hotspot changes; binds the process to Wi-Fi
  /// while it is connected. Changes arrive through [LanFlutterApi].
  void startMonitoring();

  void stopMonitoring();

  LanSnapshot currentSnapshot();

  /// Lets broadcast and multicast packets through Wi-Fi power saving.
  void acquireMulticastLock();

  void releaseMulticastLock();

  AppInfo appInfo();
}

@FlutterApi()
abstract class LanFlutterApi {
  void onLanChanged(LanSnapshot snapshot);
}
