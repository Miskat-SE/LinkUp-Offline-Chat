import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/connection/connection_method.dart';
import 'package:resqmesh/core/connection/connection_providers.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/identity/username.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/presentation/chat_format.dart';
import 'package:resqmesh/features/chat/presentation/new_chat_sheet.dart';
import 'package:resqmesh/shared/widgets/connection_status_card.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/name_clash_banner.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// Home: network status and the chat list (spec §6, §24).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = ref.watch(identityProvider).username ?? '';
    final method =
        ref.watch(connectionMethodProvider) ?? ConnectionMethod.wifiRouter;
    final nearby = ref.watch(nearbyProvider);
    final conversations = ref.watch(conversationsProvider).value ?? const [];
    final online = {
      for (final p in nearby.peers)
        if (p.link == LinkState.connected) p.peer.deviceId,
    };
    final query = Username.key(_query);
    final shown = query.isEmpty
        ? conversations
        : conversations
              .where(
                (c) =>
                    Username.key(c.peerName).contains(query) ||
                    c.lastMessage.preview.toLowerCase().contains(query),
              )
              .toList();

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
                if (conversations.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search chats',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          if (conversations.isEmpty)
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
                      'Tap New chat, or open someone in People, to start '
                      'a conversation.',
                ),
              ),
            )
          else if (shown.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: Text('No chats match your search.')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                96,
              ),
              sliver: SliverList.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) => _ConversationTile(
                  summary: shown[index],
                  online: online.contains(shown[index].peerId),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.summary, required this.online});

  final ConversationSummary summary;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = summary.lastMessage;
    final unread = summary.unreadCount;
    final (statusIconData, statusText) = statusIcon(last.status);
    return ListTile(
      onTap: () => context.push(Routes.chat(summary.peerId)),
      leading: Stack(
        children: [
          if (summary.peerId == ChatMessage.everyone)
            CircleAvatar(
              radius: 26,
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                Icons.campaign_rounded,
                color: scheme.onTertiaryContainer,
              ),
            )
          else
            UserAvatar(name: summary.peerName, seed: summary.peerId, size: 52),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E9E4F),
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 3),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              summary.peerName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            listTimeLabel(context, last.createdAt, clock.now()),
            style: theme.textTheme.labelMedium?.copyWith(
              color: unread > 0 ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (last.isOutgoing) ...[
            Icon(
              statusIconData,
              size: 16,
              semanticLabel: statusText,
              color: last.status == MessageStatus.failed
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Text(
              last.isOutgoing ? 'You: ${last.preview}' : last.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: unread > 0 ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: unread > 0 ? FontWeight.w600 : null,
              ),
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: AppSpacing.sm),
            Badge(
              label: Text('$unread'),
              backgroundColor: scheme.primary,
              textColor: scheme.onPrimary,
              largeSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
            ),
          ],
        ],
      ),
    );
  }
}
