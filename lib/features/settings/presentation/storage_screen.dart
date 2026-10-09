import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/storage/database_providers.dart';

/// Settings → Storage (PROJECT_PLAN.md §8.3). P5 has messages only; files
/// join in P6.
class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  bool _clearing = false;

  Future<void> _clearHistory(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: const Icon(Icons.delete_sweep_rounded),
          title: const Text('Clear chat history?'),
          content: Text(
            'All ${messageCountLabel(count)} on this phone will be deleted, '
            'including messages still waiting to be sent. Other people keep '
            "their copies. This can't be undone.",
          ),
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
              child: const Text('Clear history'),
            ),
          ],
        );
      },
    );
    if (!(confirmed ?? false) || !mounted) return;
    setState(() => _clearing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(storageManagerProvider).clearChatHistory();
      messenger.showSnackBar(
        const SnackBar(content: Text('Chat history cleared')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't clear chat history")),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = ref.watch(messageCountProvider).value;
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
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Messages', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          count == null
                              ? '…'
                              : count == 0
                              ? 'No messages saved'
                              : '${messageCountLabel(count)} saved',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Your chats are saved only on this phone. Nothing is stored '
              'online.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              enabled: !_clearing && (count ?? 0) > 0,
              leading: Icon(Icons.delete_sweep_rounded, color: scheme.error),
              title: const Text('Clear chat history'),
              subtitle: const Text('Delete all messages on this phone'),
              trailing: _clearing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: () => _clearHistory(count ?? 0),
            ),
          ),
        ],
      ),
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
