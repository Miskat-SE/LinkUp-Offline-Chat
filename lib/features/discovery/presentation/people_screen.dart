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
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/core/settings/developer_mode.dart';
import 'package:resqmesh/core/utils/relative_time.dart';
import 'package:resqmesh/features/discovery/domain/display_names.dart';
import 'package:resqmesh/shared/widgets/connection_status_card.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

const _onlineGreen = Color(0xFF2E9E4F);

/// People Nearby (spec §7): every device found on the local network. A
/// device is "Online" once a connection to it is up.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final method =
        ref.watch(connectionMethodProvider) ?? ConnectionMethod.wifiRouter;
    final nearby = ref.watch(nearbyProvider);
    final developer = ref.watch(developerModeProvider);
    final labels = displayNames([
      for (final p in nearby.peers)
        (deviceId: p.peer.deviceId, name: p.peer.name),
    ], selfName: ref.watch(identityProvider).username);
    List<NearbyPeer> withLink(Set<LinkState> links) =>
        nearby.peers.where((p) => links.contains(p.link)).toList();
    final online = withLink({LinkState.connected});
    final reaching = withLink({LinkState.connecting, LinkState.unreachable});
    final earlier = withLink({LinkState.offline});

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

    Widget card(NearbyPeer person) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _PersonCard(
        person: person,
        label: labels[person.peer.deviceId]!,
        showDetails: developer,
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('People Nearby'),
            actions: [
              IconButton(
                tooltip: 'Send to several people',
                onPressed: () => context.push(Routes.selectPeople()),
                icon: const Icon(Icons.checklist_rounded),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            sliver: SliverList.list(
              children: [
                ConnectionStatusCard(
                  method: method,
                  nearby: nearby,
                  onChange: () => context.push(Routes.connection),
                ),
                if (online.isNotEmpty) ...[
                  section('Online · ${online.length}'),
                  for (final person in online) card(person),
                ],
                if (reaching.isNotEmpty) ...[
                  section('Nearby'),
                  for (final person in reaching) card(person),
                ],
                if (earlier.isNotEmpty) ...[
                  section('Seen earlier'),
                  for (final person in earlier) card(person),
                ],
              ],
            ),
          ),
          if (nearby.peers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NobodyYet(status: nearby.status, method: method),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }
}

class _NobodyYet extends StatelessWidget {
  const _NobodyYet({required this.status, required this.method});

  final NearbyStatus status;
  final ConnectionMethod method;

  @override
  Widget build(BuildContext context) => switch (status) {
    // Wi-Fi Direct has no network until a group forms.
    _ when method == ConnectionMethod.wifiDirect => const EmptyState(
      compact: true,
      icon: Icons.radar_rounded,
      title: 'Looking for people nearby…',
      message:
          'People nearby who open ${Brand.name} with Wi-Fi Direct will appear '
          'here.',
    ),
    _ when method == ConnectionMethod.bluetooth => const EmptyState(
      compact: true,
      icon: Icons.bluetooth_searching_rounded,
      title: 'Looking for people nearby…',
      message:
          'People within about 10 m who open ${Brand.name} with Bluetooth '
          'will appear here.',
    ),
    NearbyStatus.noNetwork => const EmptyState(
      compact: true,
      icon: Icons.wifi_off_rounded,
      title: 'Not connected',
      message:
          'Join the same Wi-Fi or hotspot as the people you want to reach.',
    ),
    NearbyStatus.blocked => const EmptyState(
      compact: true,
      icon: Icons.block_rounded,
      title: 'Local network access is off',
      message:
          'Allow ${Brand.name} to use the local network in Android settings.',
    ),
    _ => const EmptyState(
      compact: true,
      icon: Icons.radar_rounded,
      title: 'Looking for people nearby…',
      message:
          'People who open ${Brand.name} on the same Wi-Fi or hotspot will '
          'appear here.',
    ),
  };
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.label,
    required this.showDetails,
  });

  final NearbyPeer person;
  final String label;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peer = person.peer;
    final (String status, Color statusColor) = switch (person.link) {
      LinkState.connected => ('Online', _onlineGreen),
      LinkState.connecting => ('Connecting…', scheme.onSurfaceVariant),
      LinkState.unreachable => ("Can't connect", scheme.error),
      LinkState.offline => (
        'Last seen ${relativeTime(peer.lastSeen, clock.now())}',
        scheme.onSurfaceVariant,
      ),
    };
    final info = person.info;
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
                    if (person.link == LinkState.connected)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _onlineGreen,
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
                          color: statusColor,
                        ),
                      ),
                      if (showDetails) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${peer.address}:${peer.tcpPort}',
                            peer.sources
                                .map((s) => s.name.toUpperCase())
                                .join('+'),
                            if (info != null) 'link ${info.direction.name}',
                            if (info?.rttMs != null) '${info!.rttMs} ms',
                            if (peer.appVersion.isNotEmpty)
                              'v${peer.appVersion}',
                          ].join(' · '),
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
                    onPressed: () => context.push(Routes.chat(peer.deviceId)),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Chat'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push(Routes.chat(peer.deviceId, attach: true)),
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Send file'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
