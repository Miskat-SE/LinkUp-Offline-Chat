import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/constants/brand.dart';

/// How each connection method is presented to the user.
final class ConnectionMethodInfo {
  const ConnectionMethodInfo({
    required this.icon,
    required this.title,
    required this.summary,
    required this.traits,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final String summary;

  /// Short facts shown as chips: speed, range, what it suits.
  final List<String> traits;

  /// What the user does to connect this way.
  final List<String> steps;

  static ConnectionMethodInfo of(ConnectionMethod method) => switch (method) {
    ConnectionMethod.wifiRouter => const ConnectionMethodInfo(
      icon: Icons.router_rounded,
      title: 'Wi-Fi network',
      summary:
          'Everyone joins the same Wi-Fi. Works even when the router has '
          'no internet.',
      traits: ['Fast', 'Large files', 'Whole building'],
      steps: [
        'Connect to the same Wi-Fi as the people you want to reach.',
        'Open ${Brand.name}. People nearby appear on their own.',
      ],
    ),
    ConnectionMethod.hotspot => const ConnectionMethodInfo(
      icon: Icons.wifi_tethering_rounded,
      title: 'Phone hotspot',
      summary:
          'No router? One phone shares a hotspot and everyone else joins it.',
      traits: ['Fast', 'Large files', 'About 30 m'],
      steps: [
        'One person turns on Hotspot. Mobile data can stay off.',
        'Everyone else joins that hotspot in Wi-Fi settings.',
        'Open ${Brand.name} on every phone.',
      ],
    ),
    ConnectionMethod.wifiDirect => const ConnectionMethodInfo(
      icon: Icons.settings_input_antenna_rounded,
      title: 'Wi-Fi Direct',
      summary: 'Phone to phone over Wi-Fi, without a router or a hotspot.',
      traits: ['Fast', 'No router', 'About 50 m'],
      steps: [
        'Turn on Wi-Fi on each phone. No network is needed.',
        'Open LinkUp. Nearby phones connect by themselves.',
        'On Android 9 or older, accept the connection request if asked.',
      ],
    ),
    ConnectionMethod.bluetooth => const ConnectionMethodInfo(
      icon: Icons.bluetooth_rounded,
      title: 'Bluetooth',
      summary: 'Works with Wi-Fi off. Best for messages; files send slowly.',
      traits: ['Messages', 'No Wi-Fi', 'About 10 m'],
      steps: [
        'Turn on Bluetooth on each phone. No pairing needed.',
        'Open LinkUp. Phones within about 10 m connect by themselves.',
      ],
    ),
  };
}
