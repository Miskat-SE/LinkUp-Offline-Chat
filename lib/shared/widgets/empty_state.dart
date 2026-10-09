import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';

/// Centered icon, title and explanation for a screen with nothing to show yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Smaller illustration and spacing, for use below other content.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.xl : AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: compact ? 88 : 120,
                height: compact ? 88 : 120,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  icon,
                  size: compact ? 40 : 56,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
