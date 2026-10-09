import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// The files about to be sent: name, size and type, each removable, then
/// **Send** (PROJECT_PLAN.md P6.1). Returns the files to send, or null.
Future<List<PickedFile>?> showSendFilesSheet(
  BuildContext context, {
  required List<PickedFile> files,
  required String peerName,
}) => showModalBottomSheet<List<PickedFile>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _SendFilesSheet(files: files, peerName: peerName),
);

class _SendFilesSheet extends StatefulWidget {
  const _SendFilesSheet({required this.files, required this.peerName});

  final List<PickedFile> files;
  final String peerName;

  @override
  State<_SendFilesSheet> createState() => _SendFilesSheetState();
}

class _SendFilesSheetState extends State<_SendFilesSheet> {
  late final List<PickedFile> _files = [...widget.files];

  /// Larger files are refused by the receiver (*Max file size*).
  static final _maxSize = const TransferPolicy().maxFileSize;

  bool _tooLarge(PickedFile file) => (file.size ?? 0) > _maxSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sendable = _files.where((f) => !_tooLarge(f)).toList();
    final total = sendable.fold<int>(0, (sum, f) => sum + (f.size ?? 0));
    final count = sendable.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send to ${widget.peerName}',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    count == 0
                        ? 'No files to send'
                        : '$count ${count == 1 ? 'file' : 'files'} · '
                              '${formatBytes(total)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final file in _files)
                    _PickedRow(
                      file: file,
                      tooLarge: _tooLarge(file),
                      onRemove: () => setState(() => _files.remove(file)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FilledButton.icon(
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(context, sendable),
                icon: const Icon(Icons.send_rounded),
                label: Text(count <= 1 ? 'Send' : 'Send $count files'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedRow extends StatelessWidget {
  const _PickedRow({
    required this.file,
    required this.tooLarge,
    required this.onRemove,
  });

  final PickedFile file;
  final bool tooLarge;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = FileKind.of(file.mimeType ?? '', file.name);
    final size = file.size;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(kindIcon(kind), color: scheme.onSecondaryContainer),
      ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        tooLarge
            ? 'Too large to send (over 4 GB)'
            : '${size == null ? '' : '${formatBytes(size)} · '}'
                  '${kindLabel(kind)}',
        style: tooLarge ? TextStyle(color: scheme.error) : null,
      ),
      trailing: IconButton(
        tooltip: 'Remove',
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}
