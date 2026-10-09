import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/discovery/discovery_engine.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/shared/widgets/name_form.dart';

/// Settings → Change name (spec §5): checks the new name on the network,
/// then re-announces it.
class ChangeNameScreen extends ConsumerWidget {
  const ChangeNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(identityProvider).username;
    return Scaffold(
      appBar: AppBar(title: const Text('Change name')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: NameForm(
            initialName: current,
            submitLabel: 'Save',
            busyMessage: 'Checking name on this network…',
            header: Text(
              'People on this Wi-Fi will see your new name.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onSubmit: (name) async {
              final changed = current == null || current != name;
              if (changed) {
                final check = await ref
                    .read(discoveryEngineProvider)
                    .checkName(name);
                if (check.outcome == NameCheckOutcome.taken) {
                  return nameTakenMessage;
                }
                // Saving re-announces the new name on the LAN at once.
                await ref.read(identityProvider.notifier).setUsername(name);
              }
              if (!context.mounted) return null;
              final messenger = ScaffoldMessenger.of(context);
              context.pop();
              if (changed) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Name changed to “$name”')),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
