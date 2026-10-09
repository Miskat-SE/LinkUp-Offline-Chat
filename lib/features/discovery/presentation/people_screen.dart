import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/discovery/peer.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/settings/developer_mode.dart';
import 'package:resqmesh/core/utils/relative_time.dart';
import 'package:resqmesh/features/discovery/domain/display_names.dart';
import 'package:resqmesh/shared/widgets/connection_status_card.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// People Nearby (spec §7): every device discovered on the local network.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final method =
        ref.watch(connectionMethodProvider) ?? ConnectionMethod.wifiRouter;
    final discovery =
        ref.watch(discoveryProvider).value ?? DiscoverySnapshot.initial;
    final developer = ref.watch(developerModeProvider);
    final labels = displayNames([
      for (final p in discovery.peers) (deviceId: p.deviceId, name: p.name),
    ], selfName: ref.watch(identityProvider).username);
    final online = discovery.peers.where((p) => p.online).toList();
    final earlier = discovery.peers.where((p) => !p.online).toList();

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleMedium),
      ),
    );

    Widget card(Peer peer) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _PeerCard(
        peer: peer,
        label: labels[peer.deviceId]!,
        showDetails: developer,
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('People Nearby')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            sliver: SliverList.list(
              children: [
                ConnectionStatusCard(
                  method: method,
                  discovery: discovery,
                  onChange: () => context.push(Routes.connection),
                ),
                if (online.isNotEmpty) ...[
                  section('Online · ${online.length}'),
                  for (final peer in online) card(peer),
                ],
                if (earlier.isNotEmpty) ...[
                  section('Seen earlier'),
                  for (final peer in earlier) card(peer),
                ],
              ],
            ),
          ),
          if (discovery.peers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NobodyYet(state: discovery.state),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _NobodyYet extends StatelessWidget {
  const _NobodyYet({required this.state});

  final LanState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    LanState.noNetwork => const EmptyState(
      compact: true,
      icon: Icons.wifi_off_rounded,
      title: 'Not connected',
      message:
          'Join the same Wi-Fi or hotspot as the people you want to reach.',
    ),
    LanState.blocked => const EmptyState(
      compact: true,
      icon: Icons.block_rounded,
      title: 'Local network access is off',
      message:
          'Allow ${Brand.name} to use the local network in Android settings.',
    ),
    LanState.searching || LanState.connected => const EmptyState(
      compact: true,
      icon: Icons.radar_rounded,
      title: 'Looking for people nearby…',
      message:
          'People who open ${Brand.name} on the same Wi-Fi or hotspot will '
          'appear here.',
    ),
  };
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.peer,
    required this.label,
    required this.showDetails,
  });

  final Peer peer;
  final String label;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = peer.online
        ? 'Online'
        : 'Last seen ${relativeTime(peer.lastSeen, clock.now())}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    UserAvatar(name: peer.name, seed: peer.deviceId, size: 52),
                    if (peer.online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E9E4F),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: scheme.surfaceContainerLow,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: peer.online
                              ? const Color(0xFF2E9E4F)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      if (showDetails) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${peer.address}:${peer.tcpPort} · '
                          '${peer.sources.map((s) => s.name.toUpperCase()).join('+')}'
                          ' · v${peer.appVersion}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Send file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chat and file sharing are coming in the next updates.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
