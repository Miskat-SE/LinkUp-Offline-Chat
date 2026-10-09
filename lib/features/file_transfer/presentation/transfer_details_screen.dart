import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/data/stored_files.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// File Transfer Details (PROJECT_PLAN.md §10): everything about one
/// transfer, live, with Pause, Resume, Cancel and Retry.
class TransferDetailsScreen extends ConsumerWidget {
  const TransferDetailsScreen({super.key, required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transfer = ref.watch(fileTransferProvider(fileId)).value;
    if (transfer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer')),
        body: const Center(child: Text('File not found')),
      );
    }
    final progress = ref.watch(transferProgressProvider(fileId)).value;
    final peerName = _peerName(ref, transfer.peerId);
    final bytes = progress?.bytes ?? transfer.bytesTransferred;
    final fraction = progress?.fraction ?? transfer.fraction;
    final active = transfer.status == TransferStatus.inProgress;
    final service = ref.read(transferServiceProvider);
    final available =
        ref.watch(storedPathProvider(fileId)) != null &&
        transfer.status == TransferStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text(transfer.isOutgoing ? 'Sending' : 'Receiving'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xxl,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Icon(
                          kindIcon(transfer.kind),
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Text(
                          transfer.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: transfer.status == TransferStatus.preparing
                          ? null
                          : fraction,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(
                        '${(fraction * 100).floor()}%',
                        style: theme.textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '${formatBytes(bytes)} of ${formatBytes(transfer.size)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    transferStatusText(
                      transfer,
                      peerName: peerName,
                      progress: progress,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          transfer.status == TransferStatus.failed ||
                              transfer.status == TransferStatus.rejected
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                _Row('Size', formatBytes(transfer.size)),
                _Row(
                  'Type',
                  '${kindLabel(transfer.kind)} · ${transfer.mimeType}',
                ),
                _Row(transfer.isOutgoing ? 'To' : 'From', peerName),
                if (active && progress?.bytesPerSecond != null)
                  _Row('Speed', formatSpeed(progress!.bytesPerSecond!)),
                if (active && progress?.timeLeft != null)
                  _Row('Time left', formatTimeLeft(progress!.timeLeft!)),
                if (transfer.sha256 != null)
                  _Row('SHA-256', '${transfer.sha256!.substring(0, 16)}…'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (available)
                FilledButton.icon(
                  onPressed: () => context.push(Routes.filePreview(fileId)),
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View'),
                ),
              if (transfer.isOutgoing && active)
                FilledButton.tonalIcon(
                  onPressed: () => service.pause(fileId),
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
                ),
              if (transfer.isOutgoing &&
                  transfer.status == TransferStatus.paused &&
                  transfer.error != TransferErrors.pausedByPeer)
                FilledButton.tonalIcon(
                  onPressed: () => service.resume(fileId),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Resume'),
                ),
              if (transfer.isOutgoing &&
                  (transfer.status == TransferStatus.failed ||
                      transfer.status == TransferStatus.rejected))
                FilledButton.tonalIcon(
                  onPressed: () => service.retry(fileId),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              if (!transfer.status.isFinished &&
                  transfer.status != TransferStatus.failed)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Cancel this transfer?'),
          content: const Text(
            'It stops on both phones. The part already received is deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel transfer'),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await ref.read(transferServiceProvider).cancel(fileId);
    }
  }
}

String _peerName(WidgetRef ref, String peerId) {
  for (final nearby in ref.watch(nearbyProvider).peers) {
    if (nearby.peer.deviceId == peerId) return nearby.peer.name;
  }
  return 'the other person';
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          value,
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
