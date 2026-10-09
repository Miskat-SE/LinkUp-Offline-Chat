import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/shared/widgets/app_mark.dart';

/// Shown while local storage and identity load. The router moves on as soon
/// as start-up finishes; there is no artificial delay.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final failed = ref.watch(coreServicesProvider).hasError;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppMark(size: 112),
                const SizedBox(height: AppSpacing.xl),
                Text(Brand.name, style: theme.textTheme.displaySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Chat and share files on your Wi-Fi.\nNo internet needed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                if (failed) ...[
                  Text(
                    "Couldn't open this phone's app storage.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(coreServicesProvider),
                    child: const Text('Try again'),
                  ),
                ] else
                  const CircularProgressIndicator(
                    semanticsLabel: 'Starting ${Brand.name}',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
