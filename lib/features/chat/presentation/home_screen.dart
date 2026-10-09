import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/features/chat/presentation/new_chat_sheet.dart';
import 'package:resqmesh/shared/widgets/connection_status_card.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/name_clash_banner.dart';

/// Home: network status and the chat list (spec §6, §24). Chats arrive with
/// messaging (P4–P5).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(identityProvider).username ?? '';
    final method =
        ref.watch(connectionMethodProvider) ?? ConnectionMethod.wifiRouter;
    final nearby = ref.watch(nearbyProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewChatSheet(context),
        icon: const Icon(Icons.edit_square),
        label: const Text('New chat'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text(Brand.name)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            sliver: SliverList.list(
              children: [
                Text(
                  'Hi, $name',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (nearby.discovery.clash != null) ...[
                  NameClashBanner(
                    onChangeName: () => context.push(Routes.changeName),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                ConnectionStatusCard(
                  method: method,
                  nearby: nearby,
                  onChange: () => context.push(Routes.connection),
                ),
                const SizedBox(height: AppSpacing.xl),
                Semantics(
                  header: true,
                  child: Text('Chats', style: theme.textTheme.titleLarge),
                ),
              ],
            ),
          ),
          const SliverFillRemaining(
            hasScrollBody: false,
            // Bottom padding keeps the message clear of the floating button.
            child: Padding(
              padding: EdgeInsets.only(bottom: 88),
              child: EmptyState(
                compact: true,
                icon: Icons.forum_rounded,
                title: 'No chats yet',
                message:
                    'Your conversations with people nearby will show up here.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
