import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/restartable_app.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/core/storage/storage_manager.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_format.dart';

/// Settings → Storage (PROJECT_PLAN.md §8.3): what is stored, and four ways
/// to free space. Each asks first and says exactly what will be lost.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

enum _StorageAction { clearCache, deleteReceived, clearHistory, clearAll }

class _StorageScreenState extends ConsumerState<StorageScreen> {
  _StorageAction? _running;

  Future<void> _run(_StorageAction action, StorageUsage usage) async {
    final (title, body, button) = _confirmation(action, usage);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(_icon(action)),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(button),
            ),
          ],
        );
      },
    );
    if (!(confirmed ?? false) || !mounted) return;
    setState(() => _running = action);
    final messenger = ScaffoldMessenger.of(context);
    final transfers = ref.read(transferServiceProvider);
    final storage = ref.read(storageManagerProvider);
    String done;
    try {
      switch (action) {
        case _StorageAction.clearCache:
          final freed = await transfers.clearCache();
          done = 'Freed ${formatBytes(freed)}';
        case _StorageAction.deleteReceived:
          final count = await transfers.deleteReceivedFiles();
          done = '${_files(count)} deleted';
        case _StorageAction.clearHistory:
          await transfers.stopAll();
          await storage.clearChatHistory();
          done = 'Chat history cleared';
        case _StorageAction.clearAll:
          await transfers.stopAll();
          await storage.clearAllLocalData(ref.read(keyValueStoreProvider));
          if (!mounted) return;
          // Start over at onboarding, as a new device.
          RestartableApp.restart(context);
          return;
      }
    } on Object {
      done = "Couldn't finish. Please try again.";
    }
    if (!mounted) return;
    setState(() => _running = null);
    ref.invalidate(storageUsageProvider);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  (String, String, String) _confirmation(
    _StorageAction action,
    StorageUsage usage,
  ) => switch (action) {
    _StorageAction.clearCache => (
      'Clear cached files?',
      'Copies of files you sent, unfinished downloads and thumbnails are '
          'deleted (${formatBytes(usage.sent.bytes + usage.cacheBytes)}). '
          "Files you've sent can't be resent afterwards. Files being sent "
          'right now are kept.',
      'Clear',
    ),
    _StorageAction.deleteReceived => (
      'Delete received files?',
      'All ${_files(usage.received.files)} you received '
          '(${formatBytes(usage.received.bytes)}) are deleted from this '
          'phone. The messages stay and show "File deleted". Files saved to '
          'Downloads are not affected.',
      'Delete files',
    ),
    _StorageAction.clearHistory => (
      'Clear chat history?',
      'All ${messageCountLabel(usage.messages)} and every shared file on '
          'this phone are deleted, including messages still waiting to be '
          "sent. Other people keep their copies. This can't be undone.",
      'Clear history',
    ),
    _StorageAction.clearAll => (
      'Clear all local data?',
      'Chats, files and your name are deleted, and this phone gets a new '
          'identity. The app starts again from the beginning. Other people '
          "keep their copies. This can't be undone.",
      'Clear everything',
    ),
  };

  static IconData _icon(_StorageAction action) => switch (action) {
    _StorageAction.clearCache => Icons.cleaning_services_rounded,
    _StorageAction.deleteReceived => Icons.folder_delete_rounded,
    _StorageAction.clearHistory => Icons.delete_sweep_rounded,
    _StorageAction.clearAll => Icons.restart_alt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usage = ref.watch(storageUsageProvider).value;
    // Recount when messages change (e.g. one arrives while this is open).
    ref.listen(messageCountProvider, (_, _) {
      ref.invalidate(storageUsageProvider);
    });

    Widget action(
      _StorageAction kind,
      String title,
      String subtitle,
      bool on,
    ) => ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      enabled: _running == null && usage != null && on,
      leading: Icon(_icon(kind), color: scheme.error),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _running == kind
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: usage == null ? null : () => _run(kind, usage),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Storage')),
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: usage == null
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      children: [
                        _UsageRow(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Messages',
                          value: usage.messages == 0
                              ? 'No messages saved'
                              : '${messageCountLabel(usage.messages)} saved',
                        ),
                        _UsageRow(
                          icon: Icons.download_done_rounded,
                          title: 'Files received',
                          value: _amount(usage.received),
                        ),
                        _UsageRow(
                          icon: Icons.upload_file_rounded,
                          title: 'Copies of sent files',
                          value: _amount(usage.sent),
                        ),
                        _UsageRow(
                          icon: Icons.hourglass_bottom_rounded,
                          title: 'Unfinished and thumbnails',
                          value: formatBytes(usage.cacheBytes),
                        ),
                        const Divider(indent: AppSpacing.xl),
                        _UsageRow(
                          icon: Icons.storage_rounded,
                          title: 'Total',
                          value: formatBytes(usage.totalBytes),
                          strong: true,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Your chats and files are saved only on this phone. Nothing is '
              'stored online.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                action(
                  _StorageAction.clearCache,
                  'Clear cached files',
                  'Copies of sent files, unfinished downloads, thumbnails',
                  (usage?.sent.bytes ?? 0) + (usage?.cacheBytes ?? 0) > 0,
                ),
                action(
                  _StorageAction.deleteReceived,
                  'Delete received files',
                  'Messages stay; their files are removed',
                  (usage?.received.files ?? 0) > 0,
                ),
                action(
                  _StorageAction.clearHistory,
                  'Clear chat history',
                  'Delete all messages and files on this phone',
                  (usage?.messages ?? 0) > 0 || (usage?.totalBytes ?? 0) > 0,
                ),
                action(
                  _StorageAction.clearAll,
                  'Clear all local data',
                  'Start again as a new device',
                  true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _amount(({int files, int bytes}) usage) => usage.files == 0
      ? 'None'
      : '${_files(usage.files)} · ${formatBytes(usage.bytes)}';
}

String _files(int count) => '$count ${count == 1 ? 'file' : 'files'}';

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.title,
    required this.value,
    this.strong = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.titleSmall
        : theme.textTheme.bodyMedium;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: style),
      trailing: Text(value, style: style),
    );
  }
}

/// "1 message", "1,234 messages".
String messageCountLabel(int count) {
  final digits = count.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return '$grouped ${count == 1 ? 'message' : 'messages'}';
}
