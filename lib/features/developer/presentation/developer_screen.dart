import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/constants/protocol_constants.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/utils/relative_time.dart';

/// Hidden diagnostics for testing on real phones (spec §34): local IP and
/// subnet, ports, peers, packet counters, errors and recent logs.
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discovery =
        ref.watch(discoveryProvider).value ?? DiscoverySnapshot.initial;
    final identity = ref.watch(identityProvider);
    final logs = ref.watch(appLoggerProvider).recent;
    final net = discovery.network;
    final now = clock.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer'),
        actions: [
          IconButton(
            tooltip: 'Announce now',
            icon: const Icon(Icons.campaign_rounded),
            onPressed: () => ref.read(discoveryEngineProvider).announceNow(),
          ),
          IconButton(
            tooltip: 'Copy logs',
            icon: const Icon(Icons.copy_all_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(
                ClipboardData(text: logs.map((e) => e.format()).join('\n')),
              );
              messenger.showSnackBar(
                const SnackBar(content: Text('Logs copied')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          _Section('This device', [
            _Row('Name', identity.username ?? '—'),
            _Row('Device ID', identity.deviceId),
          ]),
          _Section('Network', [
            _Row('Status', discovery.state.name),
            _Row('Wi-Fi joined', _yesNo(net.wifiConnected)),
            _Row('Bound to Wi-Fi', _yesNo(net.boundToWifi)),
            _Row('Sharing hotspot', _yesNo(net.isHotspotHost)),
            if (net.interfaces.isEmpty) const _Row('Interfaces', 'none'),
            for (final i in net.interfaces)
              _Row(
                i.name,
                '${i.address}/${i.prefixLength} (${i.kind.name})\n'
                'subnet ${i.subnet} · broadcast ${i.broadcast}',
              ),
            _Row(
              'Router isolation suspected',
              _yesNo(discovery.isolationSuspected),
            ),
          ]),
          _Section('Ports', [
            _Row(
              'UDP discovery',
              discovery.udpPort == null
                  ? 'not bound'
                  : 'listening on ${discovery.udpPort}',
            ),
            const _Row(
              'TCP',
              '${ProtocolConstants.tcpPort} advertised (connections in P3)',
            ),
            _Row('NSD', discovery.nsdEnabled ? 'browsing' : 'off'),
          ]),
          _Section('Peers · ${discovery.onlineCount} online', [
            if (discovery.peers.isEmpty) const _Row('—', 'none yet'),
            for (final p in discovery.peers)
              _Row(
                '${p.name} · ${p.shortId}',
                '${p.online ? 'online' : 'offline'} · ${p.address}:${p.tcpPort}'
                    ' · ${p.sources.map((s) => s.name).join('+')}'
                    ' · seen ${relativeTime(p.lastSeen, now)} · v${p.appVersion}',
              ),
          ]),
          _Section('Packets', [
            _Row('Sent', _counts(discovery.stats.sent)),
            _Row('Received', _counts(discovery.stats.received)),
            _Row('Malformed', '${discovery.stats.malformed}'),
            _Row('Other apps', '${discovery.stats.foreign}'),
          ]),
          _Section('Network errors', [
            if (discovery.stats.recentErrors.isEmpty) const _Row('—', 'none'),
            for (final e in discovery.stats.recentErrors.reversed) _Row('', e),
          ]),
          _Section('Recent logs', [
            for (final entry in logs.reversed.take(100))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  entry.format(),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  static String _yesNo(bool value) => value ? 'yes' : 'no';

  static String _counts(Map<String, int> counts) => counts.isEmpty
      ? '0'
      : (counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${e.key} ${e.value}')
            .join('\n');
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
