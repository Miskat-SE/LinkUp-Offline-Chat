import 'dart:async';
import 'dart:math';

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
import 'package:resqmesh/features/file_transfer/data/file_picker_service.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';
import 'package:resqmesh/features/file_transfer/data/transfer_service.dart';
import 'package:resqmesh/features/file_transfer/domain/file_transfer.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_message_card.dart';
import 'package:resqmesh/features/file_transfer/presentation/send_files_sheet.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// One-to-one chat (spec §8, §25).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.peerId, this.attach = false});

  final String peerId;

  /// Opens the file picker right away (People → Send file).
  final bool attach;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _text = TextEditingController();
  late final ActiveChat _activeChat = ref.read(activeChatProvider.notifier);
  ChatMessage? _replyingTo;

  /// Android is copying picked files into the app (large picks take a
  /// moment).
  bool _gettingFiles = false;

  String get _peerId => widget.peerId;

  /// The Everyone thread (P7): one message to everyone online.
  bool get _everyone => _peerId == ChatMessage.everyone;

  /// Names of the people online now, for Everyone messages.
  Map<String, String> _onlineNames() => {
    for (final p in ref.read(nearbyProvider).peers)
      if (p.link == LinkState.connected) p.peer.deviceId: p.peer.name,
  };

  void _nobodyOnline() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Nobody is online to receive it')),
  );

  @override
  void initState() {
    super.initState();
    // Providers can't change while widgets build, so after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeChat.open(_peerId);
      unawaited(ref.read(appNotificationsProvider).cancelConversation(_peerId));
      _markRead();
      unawaited(() async {
        await _offerNotifications();
        if (widget.attach && mounted && !_everyone) await _attach(_name());
      }());
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
    if (_everyone) {
      final sent = await ref
          .read(messagingServiceProvider)
          .sendToEveryone(
            text: text,
            names: _onlineNames(),
            replyToId: replyTo?.id,
          );
      if (sent.isEmpty && mounted) _nobodyOnline();
      return;
    }
    await ref
        .read(messagingServiceProvider)
        .sendText(
          peerId: _peerId,
          peerName: peerName,
          text: text,
          replyToId: replyTo?.id,
        );
  }

  String _name() {
    for (final p in ref.read(nearbyProvider).peers) {
      if (p.peer.deviceId == _peerId) return p.peer.name;
    }
    return 'Unknown';
  }

  /// Attach: pick files, confirm them in a sheet, send one message each.
  Future<void> _attach(String peerName) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<PickedFile> picked;
    try {
      picked = await ref
          .read(filePickerProvider)
          .pick(
            onBusy: (busy) {
              if (mounted) setState(() => _gettingFiles = busy);
            },
          );
    } on Object {
      if (mounted) setState(() => _gettingFiles = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't open those files")),
      );
      return;
    }
    if (!mounted || picked.isEmpty) return;
    final files = await showSendFilesSheet(
      context,
      files: picked,
      peerName: peerName,
    );
    if (files == null || files.isEmpty) return;
    if (_everyone) {
      final sent = await ref
          .read(messagingServiceProvider)
          .sendToEveryone(files: files, names: _onlineNames());
      if (sent.isEmpty && mounted) _nobodyOnline();
      return;
    }
    await ref
        .read(messagingServiceProvider)
        .sendFiles(peerId: _peerId, peerName: peerName, files: files);
  }

  Future<void> _showActions(ChatMessage message) async {
    final action = await showModalBottomSheet<_Action>(
      context: context,
      builder: (context) => _MessageActions(
        message: message,
        canReply: true,
        canRetry: message.isBroadcast
            ? (ref.read(recipientsProvider(_peerId)).value?[message.id] ?? [])
                  .any((r) => r.status == MessageStatus.failed)
            : message.status == MessageStatus.failed,
      ),
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
    final online = nearby.connectedCount;
    final name = _everyone
        ? 'Everyone'
        : person?.peer.name ??
              (messages.isNotEmpty ? messages.last.peerName : 'Unknown');
    final connected = _everyone
        ? online > 0
        : person?.link == LinkState.connected;
    final recipients = _everyone
        ? ref.watch(recipientsProvider(_peerId)).value ?? const {}
        : const <String, List<MessageRecipient>>{};

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
            if (_everyone)
              const _EveryoneAvatar(size: 40)
            else
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
                    _everyone
                        ? (online == 0 ? 'Nobody online' : '$online online now')
                        : _presence(person),
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
                      icon: _everyone
                          ? Icons.campaign_rounded
                          : Icons.waving_hand_rounded,
                      title: _everyone
                          ? 'Talk to everyone nearby'
                          : 'Say hello to $name',
                      message: _everyone
                          ? 'One message reaches every phone that is online '
                                'right now.'
                          : connected
                          ? 'Messages go straight to their phone.'
                          : 'They will get your messages when they are '
                                'back on this network.',
                    )
                  : _MessageList(
                      messages: messages,
                      peerName: name,
                      recipients: recipients,
                      onLongPress: _showActions,
                      onReply: (m) => setState(() => _replyingTo = m),
                      onRetry: (m) =>
                          ref.read(messagingServiceProvider).retry(m.id),
                      onShowDelivery: (m) => showDeliverySheet(
                        context,
                        recipients: recipients[m.id] ?? const [],
                        onRetry: () =>
                            ref.read(messagingServiceProvider).retry(m.id),
                      ),
                    ),
            ),
            if (!connected)
              _OfflineNote(
                text: _everyone
                    ? 'Nobody is online. Everyone messages reach only the '
                          'people online when you send.'
                    : "$name isn't connected. Messages will send when "
                          "they're back.",
              ),
            if (_replyingTo != null)
              _ReplyBar(
                message: _replyingTo!,
                author: _authorOf(_replyingTo!, name),
                onClose: () => setState(() => _replyingTo = null),
              ),
            if (_gettingFiles) const LinearProgressIndicator(),
            _Composer(
              controller: _text,
              // Everyone goes only to people online now.
              enabled: !_everyone || connected,
              onSend: () => _send(name),
              onAttach: _gettingFiles || (_everyone && !connected)
                  ? null
                  : () => _attach(_everyone ? 'everyone online' : name),
            ),
          ],
        ),
      ),
    );
  }

  /// Who wrote [message], as a quote shows it.
  static String _authorOf(ChatMessage message, String peerName) =>
      message.isOutgoing
      ? 'You'
      : (message.isBroadcast ? message.peerName : peerName);

  static String _presence(NearbyPeer? person) => switch (person?.link) {
    LinkState.connected => 'Online',
    LinkState.connecting => 'Connecting…',
    LinkState.unreachable => "Can't connect",
    LinkState.offline =>
      'Last seen ${relativeTime(person!.peer.lastSeen, clock.now())}',
    null => 'Offline',
  };
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.messages,
    required this.peerName,
    required this.onLongPress,
    required this.onReply,
    required this.onRetry,
    required this.onShowDelivery,
    this.recipients = const {},
  });

  /// Oldest first.
  final List<ChatMessage> messages;
  final String peerName;
  final void Function(ChatMessage) onLongPress;

  /// Swiping a message to the right replies to it.
  final void Function(ChatMessage) onReply;
  final void Function(ChatMessage) onRetry;
  final void Function(ChatMessage) onShowDelivery;

  /// Everyone thread: who each outgoing message went to.
  final Map<String, List<MessageRecipient>> recipients;

  static const _groupGap = Duration(minutes: 2);

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};
  String? _highlighted;
  Timer? _unhighlight;

  @override
  void dispose() {
    _scroll.dispose();
    _unhighlight?.cancel();
    super.dispose();
  }

  /// Scrolls up to an older message (building the list as it goes), then
  /// tints it for a moment.
  Future<void> _showMessage(String id) async {
    final duration = AppMotion.of(context, AppMotion.medium);
    for (var step = 0; step < 40 && mounted; step++) {
      final target = _keys[id]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: duration,
          curve: AppMotion.standard,
        );
        if (!mounted) return;
        setState(() => _highlighted = id);
        _unhighlight?.cancel();
        _unhighlight = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _highlighted = null);
        });
        return;
      }
      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _scroll.jumpTo(
        min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    final peerName = widget.peerName;
    final recipients = widget.recipients;
    final now = clock.now();
    final byId = {for (final m in messages) m.id: m};
    bool sameDay(ChatMessage a, ChatMessage b) =>
        DateUtils.isSameDay(a.createdAt.toLocal(), b.createdAt.toLocal());
    bool grouped(ChatMessage a, ChatMessage b) =>
        a.isOutgoing == b.isOutgoing &&
        sameDay(a, b) &&
        b.createdAt.difference(a.createdAt).abs() < _MessageList._groupGap;

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
        _SwipeToReply(
          key: _keys.putIfAbsent(message.id, GlobalKey.new),
          onReply: () => widget.onReply(message),
          child: MessageBubble(
            message: message,
            peerName: peerName,
            repliedTo: repliedTo,
            repliedToAuthor: repliedTo == null
                ? ''
                : _ChatScreenState._authorOf(repliedTo, peerName),
            onTapQuote: repliedTo == null
                ? null
                : () => unawaited(_showMessage(repliedTo.id)),
            highlighted: _highlighted == message.id,
            groupedWithPrevious: previous != null && grouped(previous, message),
            groupedWithNext: next != null && grouped(message, next),
            onLongPress: () => widget.onLongPress(message),
            senderLabel: message.isBroadcast && !message.isOutgoing
                ? message.peerName
                : null,
            delivery: message.isBroadcast && message.isOutgoing
                ? DeliverySummary(recipients[message.id] ?? const [])
                : null,
            onTapDelivery: () => widget.onShowDelivery(message),
            attachment: message.fileId == null
                ? null
                : (foreground) => message.isBroadcast && message.isOutgoing
                      ? _BroadcastFileCard(
                          message: message,
                          recipients: recipients[message.id] ?? const [],
                          foreground: foreground,
                        )
                      : FileMessageCard(
                          fileId: message.fileId!,
                          peerName: message.isBroadcast
                              ? message.peerName
                              : peerName,
                          foreground: foreground,
                        ),
            onTapFailed: () => widget.onRetry(message),
          ),
        ),
      );
    }
    final shown = items.reversed.toList();
    return ListView.builder(
      controller: _scroll,
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
  const _OfflineNote({required this.text});

  final String text;

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
              text,
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
                  message.preview,
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
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.enabled = true,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final bool enabled;

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
    final canSend = widget.enabled && widget.controller.text.trim().isNotEmpty;
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
          IconButton(
            tooltip: 'Attach files',
            onPressed: widget.onAttach,
            style: IconButton.styleFrom(minimumSize: const Size(48, 52)),
            icon: const Icon(Icons.attach_file_rounded),
          ),
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
  const _MessageActions({
    required this.message,
    required this.canReply,
    required this.canRetry,
  });

  final ChatMessage message;
  final bool canReply;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canReply)
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, _Action.reply),
            ),
          if (!message.isFile)
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(context, _Action.copy),
            ),
          if (canRetry)
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

class _EveryoneAvatar extends StatelessWidget {
  const _EveryoneAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.campaign_rounded,
        size: size * 0.55,
        color: scheme.onTertiaryContainer,
      ),
    );
  }
}

/// A file sent to everyone: one card, with how many people have it.
class _BroadcastFileCard extends ConsumerWidget {
  const _BroadcastFileCard({
    required this.message,
    required this.recipients,
    required this.foreground,
  });

  final ChatMessage message;
  final List<MessageRecipient> recipients;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = [
      for (final r in recipients)
        if (r.fileId != null) ref.watch(fileTransferProvider(r.fileId!)).value,
    ].nonNulls.toList();
    final total = recipients.length;
    final done = transfers
        .where((t) => t.status == TransferStatus.completed)
        .length;
    final moving = transfers
        .where((t) => t.status == TransferStatus.inProgress)
        .length;
    final failed = transfers
        .where(
          (t) =>
              t.status == TransferStatus.failed ||
              t.status == TransferStatus.rejected,
        )
        .length;
    final preparing = transfers.any(
      (t) => t.status == TransferStatus.preparing,
    );
    final status = [
      if (preparing)
        'Preparing…'
      else if (done == total)
        'Received by all $total'
      else ...[
        if (done > 0) 'Received by $done of $total',
        if (moving > 0) 'Sending to $moving',
        if (done == 0 && moving == 0 && failed == 0) 'Waiting to send',
      ],
      if (failed > 0) '$failed not sent',
    ].join(' · ');
    return FileMessageCard(
      fileId: message.fileId!,
      peerName: 'everyone',
      foreground: foreground,
      statusOverride: status,
    );
  }
}

/// Who an Everyone message reached, person by person.
Future<void> showDeliverySheet(
  BuildContext context, {
  required List<MessageRecipient> recipients,
  required VoidCallback onRetry,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final theme = Theme.of(context);
    final failed = recipients.any((r) => r.status == MessageStatus.failed);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text('Sent to', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final r in recipients)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
              ),
              leading: UserAvatar(name: r.recipientName, seed: r.recipientId),
              title: Text(r.recipientName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _recipientStatus(r.status),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: r.status == MessageStatus.failed
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(statusIcon(r.status).$1, size: 18),
                ],
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.pop(context);
                  onRetry();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry for those not sent'),
              ),
            )
          else
            const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  },
);

String _recipientStatus(MessageStatus status) => switch (status) {
  MessageStatus.pending => 'Waiting',
  MessageStatus.sending => 'Sending',
  MessageStatus.sent => 'Sent',
  MessageStatus.delivered => 'Delivered',
  MessageStatus.read => 'Read',
  MessageStatus.failed => 'Not sent',
  MessageStatus.received => '',
};

/// Swipe a message to the right to reply (P15.2). The bubble follows the
/// finger; past the threshold a reply icon shows and the phone ticks.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({super.key, required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _trigger = 64.0;
  static const _furthest = 96.0;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: AppMotion.short,
  )..addListener(() => setState(() => _dx = _from * (1 - _back.value)));
  double _dx = 0;
  double _from = 0;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails details) {
    _back.stop();
    setState(() => _dx = (_dx + details.delta.dx).clamp(0, _furthest));
    final armed = _dx >= _trigger;
    if (armed && !_armed) unawaited(HapticFeedback.selectionClick());
    _armed = armed;
  }

  void _release() {
    if (_armed) widget.onReply();
    _armed = false;
    _from = _dx;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dx = 0);
    } else {
      unawaited(_back.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragUpdate: _update,
    onHorizontalDragEnd: (_) => _release(),
    onHorizontalDragCancel: _release,
    child: Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (_dx > 0)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
            child: Opacity(
              opacity: (_dx / _trigger).clamp(0, 1),
              child: Icon(
                Icons.reply_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        Transform.translate(offset: Offset(_dx, 0), child: widget.child),
      ],
    ),
  );
}
