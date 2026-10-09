import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
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
  StreamSubscription<String>? _opened;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => ref
          .read(appInForegroundProvider.notifier)
          .set(foreground: state == AppLifecycleState.resumed),
    );
    final notifications = ref.read(appNotificationsProvider);
    _opened = notifications.opened.listen(_openChat);
    unawaited(
      notifications.takeLaunchConversation().then((id) {
        if (id != null) _openChat(id);
      }),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_opened?.cancel());
    super.dispose();
  }

  void _openChat(String peerId) {
    if (!mounted) return;
    context.push(Routes.chat(peerId));
  }

  @override
  Widget build(BuildContext context) {
    // Keep messaging and its notifications running while the app is open.
    ref
      ..watch(messagingServiceProvider)
      ..watch(messageAlertsProvider);
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
