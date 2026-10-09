import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';

/// Shown while another device on the network holds this device's name
/// (PROJECT_PLAN.md §6.4). Stays until the name is changed.
class NameClashBanner extends StatelessWidget {
  const NameClashBanner({super.key, required this.onChangeName});

  final VoidCallback onChangeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.badge_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Your name is also used by another device on this network.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(48, 40),
                ),
                onPressed: onChangeName,
                child: const Text('Change name'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
