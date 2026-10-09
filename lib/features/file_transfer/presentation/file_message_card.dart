import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/data/stored_files.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// A file inside a chat bubble: preview or icon, name, size, live progress
/// and the one action that fits its state. Tap opens the file when it is
/// here, otherwise the transfer details.
class FileMessageCard extends ConsumerWidget {
  const FileMessageCard({
    super.key,
    required this.fileId,
    required this.peerName,
    required this.foreground,
    this.statusOverride,
  });

  final String fileId;
  final String peerName;

  /// Text colour of the surrounding bubble.
  final Color foreground;

  /// A file sent to several people: their combined status replaces this
  /// transfer's own, without per-transfer controls.
  final String? statusOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transfer = ref.watch(fileTransferProvider(fileId)).value;
    if (transfer == null) {
      return Text(
        'File',
        style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
      );
    }
    final progress = ref.watch(transferProgressProvider(fileId)).value;
    final status =
        statusOverride ??
        transferStatusText(transfer, peerName: peerName, progress: progress);
    final stored = ref.watch(storedPathProvider(fileId)) != null;
    // The sender's own copy can be viewed whatever happened to one copy.
    final available =
        stored &&
        (transfer.status == TransferStatus.completed || statusOverride != null);
    final showsBar =
        transfer.status == TransferStatus.preparing ||
        (statusOverride == null &&
            (transfer.status == TransferStatus.inProgress ||
                transfer.status == TransferStatus.paused));
    final muted = foreground.withValues(alpha: 0.75);

    return Semantics(
      label: '${transfer.name}, ${formatBytes(transfer.size)}. $status',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(
          available ? Routes.filePreview(fileId) : Routes.fileDetails(fileId),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (available && transfer.kind == FileKind.image)
                _ImagePreview(fileId: fileId),
              if (available && transfer.kind == FileKind.video)
                _VideoPreview(fileId: fileId),
              Row(
                children: [
                  _KindBadge(kind: transfer.kind, color: foreground),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                        Text(
                          '${formatBytes(transfer.size)} · '
                          '${kindLabel(transfer.kind)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (statusOverride == null)
                    _TransferAction(transfer: transfer, color: foreground)
                  else
                    const SizedBox(width: AppSpacing.xs),
                ],
              ),
              if (showsBar) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: transfer.status == TransferStatus.preparing
                        ? null
                        : (progress?.fraction ?? transfer.fraction),
                    color: foreground,
                    backgroundColor: foreground.withValues(alpha: 0.2),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color:
                      transfer.status == TransferStatus.failed ||
                          transfer.status == TransferStatus.rejected
                      ? theme.colorScheme.error
                      : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.color});

  final FileKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    child: Icon(kindIcon(kind), color: color),
  );
}

/// Pause, resume, retry or cancel: whichever fits the state.
class _TransferAction extends ConsumerWidget {
  const _TransferAction({required this.transfer, required this.color});

  final FileTransfer transfer;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(transferServiceProvider);
    final id = transfer.fileId;
    final (IconData, String, Future<void> Function())? action = switch ((
      transfer.status,
      transfer.isOutgoing,
    )) {
      (TransferStatus.inProgress, true) => (
        Icons.pause_rounded,
        'Pause',
        () => service.pause(id),
      ),
      (TransferStatus.paused, true)
          when transfer.error != TransferErrors.pausedByPeer =>
        (Icons.play_arrow_rounded, 'Resume', () => service.resume(id)),
      (TransferStatus.failed || TransferStatus.rejected, true) => (
        Icons.refresh_rounded,
        'Retry',
        () => service.retry(id),
      ),
      (
        TransferStatus.preparing ||
            TransferStatus.offered ||
            TransferStatus.queued ||
            TransferStatus.paused,
        true,
      ) ||
      (
        TransferStatus.offered ||
            TransferStatus.inProgress ||
            TransferStatus.paused,
        false,
      ) => (Icons.close_rounded, 'Cancel', () => service.cancel(id)),
      _ => null,
    };
    if (action == null) return const SizedBox(width: AppSpacing.xs);
    final (icon, tooltip, run) = action;
    return IconButton(
      tooltip: tooltip,
      onPressed: run,
      icon: Icon(icon, color: color),
    );
  }
}

class _ImagePreview extends ConsumerWidget {
  const _ImagePreview({required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(storedPathProvider(fileId));
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image(
            image: storedImage(path, width: 720),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _VideoPreview extends ConsumerWidget {
  const _VideoPreview({required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(videoThumbnailProvider(fileId)).value;
    if (thumb == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Image(
                image: storedImage(thumb, width: 720),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox(height: 120),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
