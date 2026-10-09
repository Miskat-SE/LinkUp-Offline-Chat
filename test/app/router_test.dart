import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/app/router.dart';

void main() {
  group('redirectFor', () {
    test('holds every screen on the splash while starting or failed', () {
      for (final state in [LaunchState.loading, LaunchState.failed]) {
        expect(redirectFor(state, Routes.home), Routes.splash);
        expect(redirectFor(state, Routes.welcome), Routes.splash);
        expect(redirectFor(state, Routes.splash), isNull);
      }
    });

    test('sends a device that has not finished onboarding there', () {
      expect(
        redirectFor(LaunchState.needsOnboarding, Routes.splash),
        Routes.welcome,
      );
      expect(
        redirectFor(LaunchState.needsOnboarding, Routes.home),
        Routes.welcome,
      );
      expect(redirectFor(LaunchState.needsOnboarding, Routes.welcome), isNull);
    });

    test('skips splash and onboarding once they are done', () {
      expect(redirectFor(LaunchState.ready, Routes.splash), Routes.home);
      expect(redirectFor(LaunchState.ready, Routes.welcome), Routes.home);
      expect(redirectFor(LaunchState.ready, Routes.settings), isNull);
      expect(redirectFor(LaunchState.ready, Routes.home), isNull);
    });
  });
}
