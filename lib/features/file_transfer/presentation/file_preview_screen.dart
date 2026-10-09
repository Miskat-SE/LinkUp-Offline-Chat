import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/platform/file_actions.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/data/stored_files.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// File Preview (PROJECT_PLAN.md §10): zoomable image, video thumbnail,
/// or a card with the file's details. Never assumes a file can be shown;
/// Open hands it to another app. Nothing opens by itself (spec §28).
class FilePreviewScreen extends ConsumerWidget {
  const FilePreviewScreen({super.key, required this.fileId});

  final String fileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfer = ref.watch(fileTransferProvider(fileId)).value;
    final path = ref.watch(storedPathProvider(fileId));
    if (transfer == null || path == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            transfer == null
                ? 'File not found'
                : 'This file is not on this phone',
          ),
        ),
      );
    }
    final kind = transfer.kind;
    final image = kind == FileKind.image;
    return Scaffold(
      backgroundColor: image ? Colors.black : null,
      appBar: AppBar(
        backgroundColor: image ? Colors.black : null,
        foregroundColor: image ? Colors.white : null,
        title: Text(transfer.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Details',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => context.push(Routes.fileDetails(fileId)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (kind) {
                FileKind.image => InteractiveViewer(
                  maxScale: 6,
                  child: Center(
                    child: Image(
                      image: storedImage(path, width: 2048),
                      errorBuilder: (_, _, _) => _FileSummary(transfer),
                    ),
                  ),
                ),
                FileKind.video => _VideoSummary(transfer: transfer, path: path),
                _ => _FileSummary(transfer),
              },
            ),
            _ActionBar(transfer: transfer, path: path, dark: image),
          ],
        ),
      ),
    );
  }
}

class _FileSummary extends StatelessWidget {
  const _FileSummary(this.transfer);

  final FileTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Icon(
                kindIcon(transfer.kind),
                size: 56,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              transfer.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${formatBytes(transfer.size)} · ${kindLabel(transfer.kind)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (transfer.kind == FileKind.apk) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Only install apps from people you trust.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoSummary extends ConsumerWidget {
  const _VideoSummary({required this.transfer, required this.path});

  final FileTransfer transfer;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(videoThumbnailProvider(transfer.fileId)).value;
    if (thumb == null) return _FileSummary(transfer);
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image(image: storedImage(thumb, width: 1080)),
          IconButton.filled(
            tooltip: 'Play',
            iconSize: 48,
            onPressed: () => _open(context, ref, transfer, path),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.transfer,
    required this.path,
    required this.dark,
  });

  final FileTransfer transfer;
  final String path;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.read(fileActionsProvider);
    final light = dark ? Colors.white : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _open(context, ref, transfer, path),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: 'Share',
            color: light,
            onPressed: () => files.share(
              path,
              name: transfer.name,
              mimeType: transfer.mimeType,
            ),
            icon: const Icon(Icons.share_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: 'Save to Downloads',
            color: light,
            onPressed: () => _save(context, ref),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Saving…')));
    final saved = await ref
        .read(fileActionsProvider)
        .saveToDownloads(
          path,
          name: transfer.name,
          mimeType: transfer.mimeType,
        );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            saved == null
                ? "Couldn't save to Downloads"
                : 'Saved to Downloads as “$saved”',
          ),
        ),
      );
  }
}

Future<void> _open(
  BuildContext context,
  WidgetRef ref,
  FileTransfer transfer,
  String path,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref
      .read(fileActionsProvider)
      .open(path, name: transfer.name, mimeType: transfer.mimeType);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No app on this phone can open this file')),
    );
  }
}
