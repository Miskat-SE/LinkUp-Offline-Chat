import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';

/// Activity (P8.5): files moving now, then recent ones. The transfer
/// notification opens here when several files are moving.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transfers = ref.watch(recentTransfersProvider).value ?? const [];
    final names = {
      for (final p in ref.watch(nearbyProvider).peers)
        p.peer.deviceId: p.peer.name,
    };
    final now = transfers.where((t) => t.status.isActive).toList();
    final earlier = transfers.where((t) => !t.status.isActive).toList();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transfers')),
      body: transfers.isEmpty
          ? const EmptyState(
              icon: Icons.swap_vert_rounded,
              title: 'No transfers yet',
              message: 'Files you send or receive appear here.',
            )
          : ListView(
              children: [
                if (now.isNotEmpty) header('Now'),
                for (final t in now) _TransferRow(t, names[t.peerId]),
                if (earlier.isNotEmpty) header('Earlier'),
                for (final t in earlier) _TransferRow(t, names[t.peerId]),
              ],
            ),
    );
  }
}

class _TransferRow extends ConsumerWidget {
  const _TransferRow(this.transfer, this.peerName);

  final FileTransfer transfer;
  final String? peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(transferProgressProvider(transfer.fileId)).value;
    final who = peerName ?? 'someone';
    final direction = transfer.isOutgoing ? 'To $who' : 'From $who';
    final status = transferStatusText(
      transfer,
      peerName: who,
      progress: progress,
    );
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(
          kindIcon(transfer.kind),
          color: scheme.onSecondaryContainer,
        ),
      ),
      title: Text(transfer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$direction · $status',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (transfer.status == TransferStatus.inProgress)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: LinearProgressIndicator(
                value: progress?.fraction ?? transfer.fraction,
              ),
            ),
        ],
      ),
      trailing: Icon(
        transfer.isOutgoing
            ? Icons.north_east_rounded
            : Icons.south_west_rounded,
        size: 18,
      ),
      onTap: () => context.push(Routes.fileDetails(transfer.fileId)),
    );
  }
}
