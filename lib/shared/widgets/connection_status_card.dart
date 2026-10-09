import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/shared/widgets/connection_method_info.dart';

/// Hero card at the top of Home and People: the chosen connection method and
/// the live network status (spec §6, §31).
class ConnectionStatusCard extends StatelessWidget {
  const ConnectionStatusCard({
    super.key,
    required this.method,
    required this.discovery,
    required this.onChange,
  });

  final ConnectionMethod method;
  final DiscoverySnapshot discovery;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ConnectionMethodInfo.of(method);
    final onCard = scheme.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(info.icon, color: scheme.onPrimary, size: 28),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discovery.network.isHotspotHost
                            ? 'Sharing your hotspot'
                            : 'Connecting with',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: onCard.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        info.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: onCard,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _StatusLine(method: method, discovery: discovery),
            if (discovery.isolationSuspected) ...[
              const SizedBox(height: AppSpacing.md),
              const _IsolationHint(),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonalIcon(
              onPressed: onChange,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Change how you connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.method, required this.discovery});

  final ConnectionMethod method;
  final DiscoverySnapshot discovery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = discovery.onlineCount;
    final (Color dot, String text) = switch (discovery.state) {
      LanState.connected => (
        const Color(0xFF2E9E4F),
        'Local network connected · $count nearby',
      ),
      LanState.searching => (const Color(0xFFF29900), 'Searching for devices…'),
      LanState.noNetwork => (
        scheme.error,
        method == ConnectionMethod.hotspot
            ? 'Not on a hotspot. Join one, or turn on yours.'
            : 'Wi-Fi disconnected',
      ),
      LanState.blocked => (scheme.error, 'Local network access is off'),
    };
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: [
          if (discovery.state == LanState.searching)
            SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: dot),
            )
          else
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spec §31 wording; never claims the app is broken.
class _IsolationHint extends StatelessWidget {
  const _IsolationHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    final style = theme.textTheme.bodyMedium?.copyWith(color: color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No nearby devices found.',
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Make sure:', style: style),
            Text('• Everyone is connected to the same Wi-Fi', style: style),
            Text(
              '• The router allows device-to-device communication',
              style: style,
            ),
            Text(
              '• The app is allowed to access the local network',
              style: style,
            ),
          ],
        ),
      ),
    );
  }
}
