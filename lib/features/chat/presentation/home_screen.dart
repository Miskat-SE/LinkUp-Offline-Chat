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
import 'package:resqmesh/core/settings/stay_reachable.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/presentation/chat_format.dart';
import 'package:resqmesh/features/chat/presentation/chat_screen.dart';
import 'package:resqmesh/features/chat/presentation/new_chat_sheet.dart';
import 'package:resqmesh/shared/widgets/connection_status_card.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/name_clash_banner.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// Home: network status and the chat list (spec §6, §24).
/// Window width from which the chat list and the open chat sit side by
/// side (Material's expanded window class, P11.4).
const twoPaneWidth = 840.0;

/// The chat open beside the list on wide screens.
final selectedChatProvider = NotifierProvider<SelectedChat, String?>(
  SelectedChat.new,
);

final class SelectedChat extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String peerId) => state = peerId;
}

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

    final wide = MediaQuery.sizeOf(context).width >= twoPaneWidth;
    final selected = wide ? ref.watch(selectedChatProvider) : null;
    void open(String peerId) => wide
        ? ref.read(selectedChatProvider.notifier).select(peerId)
        : context.push(Routes.chat(peerId));

    final list = Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewChatSheet(context),
        icon: const Icon(Icons.edit_square),
        label: const Text('New chat'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text(Brand.name),
            actions: [
              IconButton(
                tooltip: 'Transfers',
                onPressed: () => context.push(Routes.activity),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
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
                const _StayReachableOffer(),
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
                  selected: shown[index].peerId == selected,
                  onTap: () => open(shown[index].peerId),
                ),
              ),
            ),
        ],
      ),
    );
    if (!wide) return list;
    return Row(
      children: [
        SizedBox(width: 400, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const Scaffold(
                  body: EmptyState(
                    compact: true,
                    icon: Icons.forum_outlined,
                    title: 'Pick a chat',
                    message: 'Your conversation opens here.',
                  ),
                )
              : ChatScreen(key: ValueKey(selected), peerId: selected),
        ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.summary,
    required this.online,
    required this.selected,
    required this.onTap,
  });

  final ConversationSummary summary;
  final bool online;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = summary.lastMessage;
    final unread = summary.unreadCount;
    final (statusIconData, statusText) = statusIcon(last.status);
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.secondaryContainer,
      onTap: onTap,
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

/// Offered once after onboarding (P8.3, §16 Q6): off unless chosen.
class _StayReachableOffer extends ConsumerStatefulWidget {
  const _StayReachableOffer();

  @override
  ConsumerState<_StayReachableOffer> createState() =>
      _StayReachableOfferState();
}

class _StayReachableOfferState extends ConsumerState<_StayReachableOffer> {
  late bool _show = !ref.read(stayReachableProvider.notifier).offered;

  Future<void> _answer({required bool on}) async {
    setState(() => _show = false);
    final setting = ref.read(stayReachableProvider.notifier);
    if (on) {
      await setting.set(on: true);
    } else {
      await setting.dismissOffer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wifi_tethering_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Stay reachable when LinkUp is closed?',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'People nearby can still send you messages and files. A '
                'small notification stays while it is on. You can change '
                'this in Settings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _answer(on: false),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.tonal(
                    onPressed: () => _answer(on: true),
                    child: const Text('Turn on'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
