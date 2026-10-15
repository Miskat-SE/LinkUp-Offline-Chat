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
  /// point), `wifiDirect` (a Wi-Fi Direct group) or `other` (e.g. Ethernet).
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

  /// Whether to bind the process to the joined Wi-Fi (default on). Off in
  /// Wi-Fi Direct mode, where traffic goes to the P2P group (ADR-0023).
  void setBindToWifi(bool bind);
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

  /// The screen a notification tap asked for (an app route such as
  /// `/chat/<id>`), once; null if none is waiting.
  String? takeOpenedRoute();
}

@FlutterApi()
abstract class NotificationFlutterApi {
  /// A notification was tapped: collect it with `takeOpenedRoute`.
  void onNotificationOpened();
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

  /// Opens the phone's camera app; the photo's path in the app cache, or
  /// null if the user backed out or there is no camera app (P15.6).
  @async
  String? takePhoto();
}

/// What the background service shows and keeps alive (PROJECT_PLAN.md §5.6).
class BackgroundState {
  BackgroundState({
    required this.transferring,
    required this.stayReachable,
    required this.title,
    required this.text,
    this.progress,
    this.route,
  });

  /// Files are moving: keep Wi-Fi and the CPU awake.
  bool transferring;

  /// Keep the app reachable while idle (Settings).
  bool stayReachable;
  String title;
  String text;

  /// 0–100, or null for an indeterminate bar or none.
  int? progress;

  /// Where a tap on the notification goes.
  String? route;
}

@HostApi()
abstract class BackgroundHostApi {
  /// Starts, updates or stops the foreground service to match [state]:
  /// running while transferring or when Stay reachable is on.
  void update(BackgroundState state);

  /// Opens Android's battery settings for this app.
  void openBatterySettings();
}

/// A LinkUp phone found through Wi-Fi Direct service discovery (ADR-0023).
class WifiDirectService {
  WifiDirectService({
    required this.deviceAddress,
    required this.deviceId,
    required this.name,
    required this.seen,
  });

  /// The phone's Wi-Fi Direct MAC address.
  String deviceAddress;

  /// LinkUp device ID.
  String deviceId;

  String name;

  /// The first 8 characters of the device IDs it has seen: a group forms
  /// only between phones that have seen each other.
  List<String> seen;
}

/// This phone's Wi-Fi Direct state.
class WifiDirectGroup {
  WifiDirectGroup({
    required this.enabled,
    required this.formed,
    required this.isOwner,
    required this.clients,
    this.networkName,
    this.passphrase,
  });

  /// Wi-Fi (and so Wi-Fi Direct) is on.
  bool enabled;

  /// This phone is in a group.
  bool formed;

  bool isOwner;

  /// Phones joined, when [isOwner].
  int clients;

  String? networkName;
  String? passphrase;
}

@HostApi()
abstract class WifiDirectHostApi {
  /// The phone has Wi-Fi Direct and runs Android 10 or newer.
  bool isSupported();

  /// `granted`, `denied` or `locationOff` (Android 8–12 need Location on).
  String permissionState();

  @async
  bool requestPermission();

  void openLocationSettings();

  /// Advertises this phone and looks for others; group changes and found
  /// phones arrive through [WifiDirectFlutterApi].
  void start(String deviceId, String name);

  /// Stops looking and leaves any group.
  void stop();

  /// Updates this phone's service record with the phones it has seen.
  void advertise(List<String> seen);

  @async
  void createGroup(String networkName, String passphrase);

  /// Joins the group with these credentials (Android 10+, no dialog).
  @async
  void joinGroup(String networkName, String passphrase);

  @async
  void leaveGroup();
}

@FlutterApi()
abstract class WifiDirectFlutterApi {
  void onServiceFound(WifiDirectService service);

  void onGroupChanged(WifiDirectGroup group);
}

/// Where a voice message's playback is (P15.7).
class VoicePlayback {
  VoicePlayback({
    required this.path,
    required this.positionMs,
    required this.durationMs,
    required this.playing,
  });

  String path;
  int positionMs;
  int durationMs;
  bool playing;
}

/// Records and plays voice messages with Android's own MediaRecorder and
/// MediaPlayer (P15.7).
@HostApi()
abstract class VoiceHostApi {
  bool hasPermission();

  @async
  bool requestPermission();

  /// Starts recording into the app cache; returns the file's path.
  String startRecording();

  /// Stops recording; its length in ms, or 0 if too short to keep (the file
  /// is then deleted).
  int stopRecording();

  void cancelRecording();

  /// Loudest level since the last call, 0–32767, for the recording meter.
  int level();

  /// Plays [path] from where it was paused, stopping anything else.
  void play(String path);

  void pause();

  void stopPlayback();
}

@FlutterApi()
abstract class VoiceFlutterApi {
  void onPlayback(VoicePlayback state);
}

/// A LinkUp phone found by Bluetooth LE scanning (P14).
class BtPeer {
  BtPeer({
    required this.address,
    required this.deviceId,
    required this.channel,
  });

  /// Bluetooth address to connect to (it changes every few minutes).
  String address;

  /// LinkUp device ID.
  String deviceId;

  /// L2CAP channel (PSM) its control connections are accepted on.
  int channel;
}

/// Bluetooth (P14): LE advertising and scanning to find phones, L2CAP
/// channels to carry the usual byte streams. Android 10+, no pairing.
@HostApi()
abstract class BluetoothHostApi {
  /// Bluetooth LE with advertising, and Android 10 or newer.
  bool isSupported();

  /// `granted`, `denied` or `locationOff` (Android 10–11 need Location on).
  String permissionState();

  @async
  bool requestPermission();

  bool isEnabled();

  /// Shows Android's "Turn on Bluetooth?" dialog.
  void requestEnable();

  void openLocationSettings();

  /// Opens an L2CAP server; returns its channel. Links it accepts arrive
  /// through [BluetoothFlutterApi.onLinkOpened] with this channel.
  @async
  int openServer();

  void closeServer(int channel);

  /// Advertises this phone ([deviceId] and its control [channel]) and scans
  /// for others.
  void startDiscovery(String deviceId, int channel);

  void stopDiscovery();

  /// Opens a link; returns its ID. Throws when the phone can't be reached.
  @async
  int connect(String address, int channel);

  /// Completes once the bytes are written to the link.
  @async
  void send(int linkId, Uint8List bytes);

  void closeLink(int linkId);
}

@FlutterApi()
abstract class BluetoothFlutterApi {
  void onPeerFound(BtPeer peer);

  /// A link accepted by the server on [channel].
  void onLinkOpened(int linkId, String address, int channel);

  void onData(int linkId, Uint8List bytes);

  void onLinkClosed(int linkId);

  void onEnabledChanged(bool enabled);
}
