import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/background_coordinator.dart';
import 'package:resqmesh/core/connection/wifi_direct_providers.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';

/// Bottom navigation between the three main tabs. Each tab keeps its own
/// navigation stack. Also keeps messaging running, tracks whether the app is
/// in the foreground, and opens chats from notification taps.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<void>? _opened;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => ref
          .read(appInForegroundProvider.notifier)
          .set(foreground: state == AppLifecycleState.resumed),
    );
    // Notification taps: a route waits on the Android side until taken,
    // whether the tap started the app or arrived while it ran.
    final notifications = ref.read(appNotificationsProvider);
    Future<void> openTapped() async {
      final route = await notifications.takeOpenedRoute();
      if (route != null && mounted) unawaited(context.push(route));
    }

    _opened = notifications.opened.listen((_) => unawaited(openTapped()));
    unawaited(openTapped());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_opened?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep messaging and its notifications running while the app is open.
    ref
      ..watch(messagingServiceProvider)
      ..watch(messageAlertsProvider)
      ..watch(backgroundCoordinatorProvider)
      // Forms Wi-Fi Direct groups while that is the chosen method.
      ..watch(wifiDirectControllerProvider);
    final shell = widget.shell;
    // Tapping the current tab again returns to its first screen.
    void go(int index) =>
        shell.goBranch(index, initialLocation: index == shell.currentIndex);
    // Landscape, foldables and tablets: a rail beside the content (P11.4).
    if (MediaQuery.sizeOf(context).width >= 600) {
      return Scaffold(
        body: SafeArea(
          right: false,
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: go,
                labelType: NavigationRailLabelType.all,
                groupAlignment: 0,
                destinations: [
                  for (final d in _destinations)
                    NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: shell),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}

const _destinations = [
  (Icons.forum_outlined, Icons.forum_rounded, 'Chats'),
  (Icons.group_outlined, Icons.group_rounded, 'People'),
  (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
];
