import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resqmesh/core/bootstrap/core_services.dart';
import 'package:resqmesh/core/identity/identity_providers.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/platform/notifications.dart';
import 'package:resqmesh/core/storage/database_providers.dart';
import 'package:resqmesh/features/chat/data/drift_message_repository.dart';
import 'package:resqmesh/features/chat/data/messaging_service.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/domain/message_repository.dart';
import 'package:resqmesh/features/file_transfer/data/file_transfer_providers.dart';

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => DriftMessageRepository(ref.watch(appDatabaseProvider)),
);

/// Sends and receives messages for the life of the app.
final messagingServiceProvider = Provider<MessagingService>((ref) {
  final engine = ref.watch(discoveryEngineProvider);
  final service = MessagingService(
    links: ref.watch(peerLinksProvider),
    repository: ref.watch(messageRepositoryProvider),
    self: () => engine.self,
    logger: ref.watch(appLoggerProvider),
    transfers: ref.watch(transferServiceProvider),
  )..start();
  ref.onDispose(() => unawaited(service.stop()));
  return service;
});

/// The chat list, most recent first.
final conversationsProvider = StreamProvider<List<ConversationSummary>>(
  (ref) => ref.watch(messageRepositoryProvider).watchConversations(),
);

/// One conversation, oldest first.
final conversationProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, peerId) =>
      ref.watch(messageRepositoryProvider).watchConversation(peerId),
);

/// Who each outgoing Everyone message went to, and how far it got.
final recipientsProvider =
    StreamProvider.family<Map<String, List<MessageRecipient>>, String>(
      (ref, conversationId) =>
          ref.watch(messageRepositoryProvider).watchRecipients(conversationId),
    );

/// The chat on screen, if any; its messages are read as they arrive and
/// don't raise notifications.
final activeChatProvider = NotifierProvider<ActiveChat, String?>(
  ActiveChat.new,
);

final class ActiveChat extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String peerId) {
    if (ref.mounted) state = peerId;
  }

  /// Safe to call after the app has closed (it is deferred from dispose).
  void close(String peerId) {
    if (ref.mounted && state == peerId) state = null;
  }
}

/// Whether the app is in the foreground (resumed).
final appInForegroundProvider = NotifierProvider<AppInForeground, bool>(
  AppInForeground.new,
);

final class AppInForeground extends Notifier<bool> {
  @override
  bool build() => true;

  void set({required bool foreground}) => state = foreground;
}

/// Shows a notification for each new message, unless its chat is on screen.
final messageAlertsProvider = Provider<void>((ref) {
  final service = ref.watch(messagingServiceProvider);
  final notifications = ref.watch(appNotificationsProvider);
  final subscription = service.incoming.listen((message) {
    final visible =
        ref.read(appInForegroundProvider) &&
        ref.read(activeChatProvider) == message.peerId;
    if (visible) return;
    unawaited(
      notifications.showMessage(
        // Everyone messages open the Everyone thread.
        conversationId: message.peerId,
        title: !message.isBroadcast
            ? message.peerName
            : message.mentions.contains(ref.read(identityProvider).deviceId)
            ? '${message.peerName} mentioned you · Everyone'
            : '${message.peerName} · Everyone',
        body: message.body,
      ),
    );
  });
  ref.onDispose(() => unawaited(subscription.cancel()));
});
