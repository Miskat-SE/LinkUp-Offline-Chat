import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/storage/key_value_store.dart';
import 'package:resqmesh/core/utils/relative_time.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/presentation/chat_format.dart';
import 'package:resqmesh/features/chat/presentation/message_bubble.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// One-to-one chat (spec §8, §25).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.peerId});

  final String peerId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _text = TextEditingController();
  late final ActiveChat _activeChat = ref.read(activeChatProvider.notifier);
  ChatMessage? _replyingTo;

  String get _peerId => widget.peerId;

  @override
  void initState() {
    super.initState();
    // Providers can't change while widgets build, so after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeChat.open(_peerId);
      unawaited(ref.read(appNotificationsProvider).cancelConversation(_peerId));
      _markRead();
      unawaited(_offerNotifications());
    });
  }

  @override
  void dispose() {
    final activeChat = _activeChat;
    final peerId = _peerId;
    // Not during dispose itself (see initState).
    Future.microtask(() => activeChat.close(peerId));
    _text.dispose();
    super.dispose();
  }

  void _markRead() {
    if (!ref.read(appInForegroundProvider)) return;
    unawaited(ref.read(messagingServiceProvider).markConversationRead(_peerId));
  }

  /// Once, the first time a chat is opened: explain, then ask (spec §17).
  Future<void> _offerNotifications() async {
    final store = ref.read(keyValueStoreProvider);
    if (store.getString(StoreKeys.notificationsAsked) != null) return;
    final notifications = ref.read(appNotificationsProvider);
    if (await notifications.allowed()) return;
    await store.setString(StoreKeys.notificationsAsked, 'yes');
    if (!mounted) return;
    final turnOn = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => const _NotificationOffer(),
    );
    if (turnOn ?? false) await notifications.requestPermission();
  }

  Future<void> _send(String peerName) async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final replyTo = _replyingTo;
    _text.clear();
    setState(() => _replyingTo = null);
    await ref
        .read(messagingServiceProvider)
        .sendText(
          peerId: _peerId,
          peerName: peerName,
          text: text,
          replyToId: replyTo?.id,
        );
  }

  Future<void> _showActions(ChatMessage message) async {
    final action = await showModalBottomSheet<_Action>(
      context: context,
      builder: (context) => _MessageActions(message: message),
    );
    if (!mounted || action == null) return;
    final service = ref.read(messagingServiceProvider);
    switch (action) {
      case _Action.reply:
        setState(() => _replyingTo = message);
      case _Action.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (!mounted) return;
        // Short, so it doesn't sit over the composer for long.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied'),
            duration: Duration(milliseconds: 1500),
          ),
        );
      case _Action.retry:
        await service.retry(message.id);
      case _Action.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete message?'),
            content: const Text(
              'It is removed from this phone only. The other person keeps '
              'their copy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await service.delete(message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearby = ref.watch(nearbyProvider);
    final messages = ref.watch(conversationProvider(_peerId)).value ?? [];
    NearbyPeer? person;
    for (final p in nearby.peers) {
      if (p.peer.deviceId == _peerId) person = p;
    }
    final name =
        person?.peer.name ??
        (messages.isNotEmpty ? messages.last.peerName : 'Unknown');
    final connected = person?.link == LinkState.connected;

    // New messages in an open chat are read at once.
    ref
      ..listen(conversationProvider(_peerId), (_, next) {
        final list = next.value ?? const <ChatMessage>[];
        if (list.any((m) => !m.isOutgoing && !m.isRead)) _markRead();
      })
      ..listen(appInForegroundProvider, (_, foreground) {
        if (foreground) _markRead();
      });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: name, seed: _peerId, size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _presence(person),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: connected
                          ? const Color(0xFF2E9E4F)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? EmptyState(
                      compact: true,
                      icon: Icons.waving_hand_rounded,
                      title: 'Say hello to $name',
                      message: connected
                          ? 'Messages go straight to their phone.'
                          : 'They will get your messages when they are '
                                'back on this network.',
                    )
                  : _MessageList(
                      messages: messages,
                      peerName: name,
                      onLongPress: _showActions,
                      onRetry: (m) =>
                          ref.read(messagingServiceProvider).retry(m.id),
                    ),
            ),
            if (!connected) _OfflineNote(name: name),
            if (_replyingTo != null)
              _ReplyBar(
                message: _replyingTo!,
                author: _replyingTo!.isOutgoing ? 'You' : name,
                onClose: () => setState(() => _replyingTo = null),
              ),
            _Composer(controller: _text, onSend: () => _send(name)),
          ],
        ),
      ),
    );
  }

  static String _presence(NearbyPeer? person) => switch (person?.link) {
    LinkState.connected => 'Online',
    LinkState.connecting => 'Connecting…',
    LinkState.unreachable => "Can't connect",
    LinkState.offline =>
      'Last seen ${relativeTime(person!.peer.lastSeen, clock.now())}',
    null => 'Offline',
  };
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.peerName,
    required this.onLongPress,
    required this.onRetry,
  });

  /// Oldest first.
  final List<ChatMessage> messages;
  final String peerName;
  final void Function(ChatMessage) onLongPress;
  final void Function(ChatMessage) onRetry;

  static const _groupGap = Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final byId = {for (final m in messages) m.id: m};
    bool sameDay(ChatMessage a, ChatMessage b) =>
        DateUtils.isSameDay(a.createdAt.toLocal(), b.createdAt.toLocal());
    bool grouped(ChatMessage a, ChatMessage b) =>
        a.isOutgoing == b.isOutgoing &&
        sameDay(a, b) &&
        b.createdAt.difference(a.createdAt).abs() < _groupGap;

    // Built oldest first, shown newest at the bottom.
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final previous = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      if (previous == null || !sameDay(previous, message)) {
        items.add(
          _DaySeparator(label: dayLabel(context, message.createdAt, now)),
        );
      }
      final repliedTo = message.replyToId == null
          ? null
          : byId[message.replyToId];
      items.add(
        MessageBubble(
          key: ValueKey(message.id),
          message: message,
          peerName: peerName,
          repliedTo: repliedTo,
          repliedToIsMine: repliedTo?.isOutgoing ?? false,
          groupedWithPrevious: previous != null && grouped(previous, message),
          groupedWithNext: next != null && grouped(message, next),
          onLongPress: () => onLongPress(message),
          onTapFailed: () => onRetry(message),
        ),
      );
    }
    final shown = items.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      itemCount: shown.length,
      itemBuilder: (context, index) => shown[index],
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "$name isn't connected. Messages will send when they're back.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.message,
    required this.author,
    required this.onClose,
  });

  final ChatMessage message;
  final String author;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        0,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $author',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                Text(
                  message.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel reply',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final canSend = widget.controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Message',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: canSend ? widget.onSend : null,
            iconSize: 26,
            style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

enum _Action { reply, copy, retry, delete }

class _MessageActions extends StatelessWidget {
  const _MessageActions({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded),
            title: const Text('Reply'),
            onTap: () => Navigator.pop(context, _Action.reply),
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy'),
            onTap: () => Navigator.pop(context, _Action.copy),
          ),
          if (message.status == MessageStatus.failed)
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Retry'),
              onTap: () => Navigator.pop(context, _Action.retry),
            ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: error),
            title: Text('Delete', style: TextStyle(color: error)),
            onTap: () => Navigator.pop(context, _Action.delete),
          ),
        ],
      ),
    );
  }
}

class _NotificationOffer extends StatelessWidget {
  const _NotificationOffer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.notifications_active_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Get notified about new messages',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${Brand.name} shows a notification when someone nearby '
              "messages you and their chat isn't open. Nothing is sent "
              'anywhere else.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Turn on notifications'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
