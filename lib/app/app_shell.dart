import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/background_coordinator.dart';
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
      ..watch(backgroundCoordinatorProvider);
    final shell = widget.shell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the current tab again returns to its first screen.
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
