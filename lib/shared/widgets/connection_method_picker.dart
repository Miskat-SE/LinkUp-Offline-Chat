import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/shared/widgets/connection_method_info.dart';

/// Selectable cards, one per connection method. The selected card expands
/// to show how to connect; methods this build can't use are marked
/// "Coming soon" and can't be selected.
class ConnectionMethodPicker extends StatelessWidget {
  const ConnectionMethodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ConnectionMethod? selected;
  final ValueChanged<ConnectionMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final method in ConnectionMethod.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _MethodCard(
              method: method,
              selected: method == selected,
              onTap: method.available ? () => onSelected(method) : null,
            ),
          ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final ConnectionMethod method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ConnectionMethodInfo.of(method);
    final enabled = onTap != null;
    final duration = AppMotion.of(context, AppMotion.medium);

    final background = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final muted = selected
        ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? null : '${info.title}, coming soon',
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.emphasized,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(
            selected ? AppRadii.lg : AppRadii.md,
          ),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              selected ? AppRadii.lg : AppRadii.md,
            ),
            child: Opacity(
              opacity: enabled ? 1 : 0.6,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _MethodIcon(icon: info.icon, selected: selected),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                info.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                info.summary,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (enabled)
                          AnimatedSwitcher(
                            duration: duration,
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              key: ValueKey(selected),
                              color: selected ? scheme.primary : scheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        // With the traits, so it wraps at large text sizes.
                        if (!enabled) const _ComingSoonBadge(),
                        for (final trait in info.traits)
                          _TraitChip(label: trait, selected: selected),
                      ],
                    ),
                    _Expand(
                      duration: duration,
                      child: selected
                          ? _Steps(steps: info.steps, color: foreground)
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animates [child]'s height; changes instantly when animations are off
/// (AnimatedSize can't take a zero duration).
class _Expand extends StatelessWidget {
  const _Expand({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.emphasized,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _MethodIcon extends StatelessWidget {
  const _MethodIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.emphasized,
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(selected ? 26 : AppRadii.md),
      ),
      child: Icon(
        icon,
        color: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? scheme.surface.withValues(alpha: 0.6)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Coming soon',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onTertiaryContainer,
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps, required this.color});

  final List<String> steps;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
