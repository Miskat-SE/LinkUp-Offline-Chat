import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/app_shell.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';
import 'package:resqmesh/features/chat/presentation/home_screen.dart';
import 'package:resqmesh/features/chat/presentation/select_people_screen.dart';
import 'package:resqmesh/features/developer/presentation/developer_screen.dart';
import 'package:resqmesh/features/discovery/presentation/people_screen.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_preview_screen.dart';
import 'package:resqmesh/features/file_transfer/presentation/transfer_details_screen.dart';
import 'package:resqmesh/features/onboarding/presentation/onboarding_screen.dart';
import 'package:resqmesh/features/onboarding/presentation/splash_screen.dart';
import 'package:resqmesh/features/settings/presentation/change_name_screen.dart';
import 'package:resqmesh/features/settings/presentation/connection_screen.dart';
import 'package:resqmesh/features/settings/presentation/settings_screen.dart';
import 'package:resqmesh/features/settings/presentation/storage_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const home = '/';
  static const people = '/people';
  static const settings = '/settings';
  static const changeName = '/settings/name';
  static const connection = '/settings/connection';
  static const developer = '/settings/developer';
  static const storage = '/settings/storage';

  static String chat(String peerId) => '/chat/$peerId';
  static String filePreview(String fileId) => '/files/$fileId';
  static String selectPeople([String? preselect]) =>
      preselect == null ? '/select' : '/select?id=$preselect';
  static String fileDetails(String fileId) => '/files/$fileId/details';
}

/// Where start-up has got to; decides which screens may be shown.
enum LaunchState { loading, failed, needsOnboarding, ready }

/// Onboarding is finished once the device has a name and a connection method.
final launchStateProvider = Provider<LaunchState>((ref) {
  return switch (ref.watch(coreServicesProvider)) {
    AsyncData() =>
      ref.watch(identityProvider).hasName &&
              ref.watch(connectionMethodProvider) != null
          ? LaunchState.ready
          : LaunchState.needsOnboarding,
    AsyncError() => LaunchState.failed,
    AsyncLoading() => LaunchState.loading,
  };
});

/// Splash while loading, onboarding until it is finished, then the app.
String? redirectFor(LaunchState launch, String location) {
  switch (launch) {
    case LaunchState.loading || LaunchState.failed:
      return location == Routes.splash ? null : Routes.splash;
    case LaunchState.needsOnboarding:
      return location == Routes.welcome ? null : Routes.welcome;
    case LaunchState.ready:
      return location == Routes.splash || location == Routes.welcome
          ? Routes.home
          : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final launch = ValueNotifier(ref.read(launchStateProvider));
  ref.listen(launchStateProvider, (_, next) => launch.value = next);
  final rootKey = GlobalKey<NavigatorState>();

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.splash,
    refreshListenable: launch,
    redirect: (context, state) =>
        redirectFor(launch.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/chat/:peerId',
        builder: (context, state) =>
            ChatScreen(peerId: state.pathParameters['peerId']!),
      ),
      GoRoute(
        path: '/select',
        builder: (context, state) =>
            SelectPeopleScreen(preselected: state.uri.queryParameters['id']),
      ),
      GoRoute(
        path: '/files/:fileId',
        builder: (context, state) =>
            FilePreviewScreen(fileId: state.pathParameters['fileId']!),
        routes: [
          GoRoute(
            path: 'details',
            builder: (context, state) =>
                TransferDetailsScreen(fileId: state.pathParameters['fileId']!),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.people,
                builder: (context, state) => const PeopleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  // Full-screen pages above the tab bar.
                  GoRoute(
                    path: 'name',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const ChangeNameScreen(),
                  ),
                  GoRoute(
                    path: 'connection',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const ConnectionScreen(),
                  ),
                  GoRoute(
                    path: 'storage',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const StorageScreen(),
                  ),
                  GoRoute(
                    path: 'developer',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const DeveloperScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    launch.dispose();
  });
  return router;
});
