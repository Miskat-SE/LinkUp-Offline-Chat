import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/platform/platform_api.g.dart';

/// Version name and build number of the installed app, from Android.
final appInfoProvider = FutureProvider<AppInfo>(
  (ref) => LanHostApi().appInfo(),
);

extension AppInfoLabel on AppInfo {
  /// `1.0.0 (3)`
  String get label => '$versionName ($versionCode)';

  /// `1.0.0+3`, as sent in HELLO (PROTOCOL.md §4.1).
  String get wireVersion => '$versionName+$versionCode';
}
