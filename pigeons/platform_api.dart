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

/// A new-message notification.
class MessageNotification {
  MessageNotification({
    required this.conversationId,
    required this.title,
    required this.body,
  });

  /// The other person's device ID; tapping opens this chat.
  String conversationId;
  String title;
  String body;
}

@HostApi()
abstract class NotificationHostApi {
  /// Whether notifications can be shown (permission on Android 13+, and the
  /// user hasn't turned them off).
  bool notificationsAllowed();

  /// Shows Android's permission prompt on Android 13+; true if allowed.
  @async
  bool requestNotificationPermission();

  void showMessageNotification(MessageNotification notification);

  /// Removes this chat's notification (the chat was opened).
  void cancelConversation(String conversationId);

  /// The chat a notification tap launched the app with, once.
  String? takeLaunchConversation();
}

@FlutterApi()
abstract class NotificationFlutterApi {
  /// A notification was tapped while the app was running.
  void onNotificationOpened(String conversationId);
}

/// Getting shared files out of the app (PROJECT_PLAN.md §8.2): files stay
/// in app-internal storage and leave only through these calls.
@HostApi()
abstract class FileHostApi {
  /// Free bytes on the storage that holds the app's files.
  int freeBytes();

  /// Opens the file in another app, shown as [displayName]; false if no
  /// installed app can open it.
  bool openFile(String path, String displayName, String mimeType);

  /// Opens Android's share sheet for the file.
  void shareFile(String path, String displayName, String mimeType);

  /// Copies the file into Downloads (asking for permission on Android 8–9)
  /// and returns the name it was saved under, or null if that failed or
  /// was not allowed.
  @async
  String? saveToDownloads(String path, String displayName, String mimeType);

  /// Writes a JPEG thumbnail of a video to [outPath]; false if Android
  /// can't read the video.
  @async
  bool videoThumbnail(String path, String outPath);
}
