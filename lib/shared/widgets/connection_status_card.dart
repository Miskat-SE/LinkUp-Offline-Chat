import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/wifi_direct_controller.dart';
import 'package:resqmesh/core/connection/wifi_direct_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/shared/widgets/connection_method_info.dart';

/// Hero card at the top of Home and People: the chosen connection method and
/// the live network status (spec §6, §31).
class ConnectionStatusCard extends ConsumerWidget {
  const ConnectionStatusCard({
    super.key,
    required this.method,
    required this.nearby,
    required this.onChange,
  });

  final ConnectionMethod method;
  final NearbySnapshot nearby;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = ConnectionMethodInfo.of(method);
    final direct = method == ConnectionMethod.wifiDirect;
    // Wi-Fi Direct explains itself until a connection is up.
    final wifiDirect = direct && nearby.status != NearbyStatus.connected
        ? ref.watch(wifiDirectStatusProvider).value
        : null;
    final controller = direct ? ref.watch(wifiDirectControllerProvider) : null;
    final action = switch (wifiDirect?.phase) {
      WifiDirectPhase.needsPermission => (
        'Allow',
        () => unawaited(controller?.requestPermission()),
      ),
      WifiDirectPhase.locationOff => (
        'Turn on Location',
        () => unawaited(controller?.openLocationSettings()),
      ),
      _ => null,
    };
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
                        nearby.discovery.network.isHotspotHost
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
            _StatusLine(method: method, nearby: nearby, wifiDirect: wifiDirect),
            if (wifiDirect?.phase == WifiDirectPhase.locationOff) ...[
              const SizedBox(height: AppSpacing.md),
              const _Hint(
                title: 'Android 12 and older need Location for Wi-Fi Direct.',
                lines: ['${Brand.name} never uses or stores your location.'],
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: action.$2, child: Text(action.$1)),
            ],
            if (direct)
              const SizedBox.shrink()
            else if (nearby.status == NearbyStatus.unreachable) ...[
              const SizedBox(height: AppSpacing.md),
              const _Hint(
                title: 'The router may be blocking device-to-device traffic.',
                lines: ['Try a phone hotspot: one shares it, the others join.'],
              ),
            ] else if (nearby.isolationSuspected) ...[
              const SizedBox(height: AppSpacing.md),
              const _Hint(
                title: 'No nearby devices found.',
                lines: [
                  'Make sure:',
                  '• Everyone is connected to the same Wi-Fi',
                  '• The router allows device-to-device communication',
                  '• The app is allowed to access the local network',
                ],
              ),
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
  const _StatusLine({
    required this.method,
    required this.nearby,
    this.wifiDirect,
  });

  final ConnectionMethod method;
  final NearbySnapshot nearby;
  final WifiDirectStatus? wifiDirect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = nearby.connectedCount;
    const waiting = Color(0xFFF29900);
    final direct = wifiDirect;
    final (Color dot, String text) = direct != null
        ? switch (direct.phase) {
            WifiDirectPhase.unsupported => (
              scheme.error,
              "This phone doesn't support Wi-Fi Direct",
            ),
            WifiDirectPhase.wifiOff => (
              scheme.error,
              'Turn on Wi-Fi to use Wi-Fi Direct',
            ),
            WifiDirectPhase.needsPermission => (
              scheme.error,
              '${Brand.name} needs permission to find nearby phones',
            ),
            WifiDirectPhase.locationOff => (
              scheme.error,
              'Turn on Location to find nearby phones',
            ),
            WifiDirectPhase.searching => (
              waiting,
              direct.nearby == 0
                  ? 'Looking for phones nearby…'
                  : 'Found ${direct.nearby} nearby, connecting…',
            ),
            WifiDirectPhase.connecting => (
              waiting,
              direct.hostName == null
                  ? 'Starting a group…'
                  : 'Joining ${direct.hostName}…',
            ),
            WifiDirectPhase.hosting => (
              waiting,
              direct.clients == 0
                  ? 'Waiting for phones to join…'
                  : 'Connecting…',
            ),
            WifiDirectPhase.joined => (
              waiting,
              'Joined ${direct.hostName ?? 'a group'}, connecting…',
            ),
          }
        : switch (nearby.status) {
            NearbyStatus.connected => (
              const Color(0xFF2E9E4F),
              'Local network connected · $count nearby',
            ),
            NearbyStatus.searching => (waiting, 'Searching for devices…'),
            NearbyStatus.unreachable => (
              scheme.error,
              "Found ${nearby.firstUnreachable?.peer.name ?? 'someone'}, "
                  "but couldn't connect",
            ),
            NearbyStatus.noNetwork => (
              scheme.error,
              method == ConnectionMethod.hotspot
                  ? 'Not on a hotspot. Join one, or turn on yours.'
                  : 'Wi-Fi disconnected',
            ),
            NearbyStatus.blocked => (
              scheme.error,
              'Local network access is off',
            ),
          };
    final spinning = dot == waiting;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        children: [
          if (spinning)
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

/// A short explanation under the status line. Uses the spec §31 wording for
/// the isolation hint, and never claims the app is broken.
class _Hint extends StatelessWidget {
  const _Hint({required this.title, required this.lines});

  final String title;
  final List<String> lines;

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
              title,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final line in lines) Text(line, style: style),
          ],
        ),
      ),
    );
  }
}
