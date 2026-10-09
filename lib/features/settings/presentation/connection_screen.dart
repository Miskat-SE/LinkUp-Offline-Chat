import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/shared/widgets/connection_method_info.dart';
import 'package:resqmesh/shared/widgets/connection_method_picker.dart';

/// Settings → How you connect.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  late ConnectionMethod _method =
      ref.read(connectionMethodProvider) ?? ConnectionMethod.wifiRouter;

  Future<void> _save() async {
    final changed = _method != ref.read(connectionMethodProvider);
    if (changed) {
      await ref.read(connectionMethodProvider.notifier).choose(_method);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    if (changed) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Now connecting with ${ConnectionMethodInfo.of(_method).title}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How you connect')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  children: [
                    ConnectionMethodPicker(
                      selected: _method,
                      onSelected: (method) => setState(() => _method = method),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
