import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/router.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/core/utils/relative_time.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// "New chat" options (spec §8, §14): one person, everyone nearby, or
/// selected people.
Future<void> showNewChatSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _NewChatSheet(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _Choice.everyone:
      await context.push(Routes.chat(ChatMessage.everyone));
      return;
    case _Choice.selected:
      await context.push(Routes.selectPeople());
      return;
    case _Choice.person:
      break;
  }
  if (!context.mounted) return;
  final peerId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _PersonPicker(),
  );
  if (peerId != null && context.mounted) {
    await context.push(Routes.chat(peerId));
  }
}

enum _Choice { person, everyone, selected }

class _NewChatSheet extends StatelessWidget {
  const _NewChatSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start a conversation', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose who should get your message.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _Option(
              icon: Icons.person_rounded,
              title: 'One person',
              body: 'A private chat with someone nearby.',
              onTap: () => Navigator.pop(context, _Choice.person),
            ),
            _Option(
              icon: Icons.campaign_rounded,
              title: 'Everyone nearby',
              body: 'Broadcast one message to all phones that are online.',
              onTap: () => Navigator.pop(context, _Choice.everyone),
            ),
            _Option(
              icon: Icons.group_add_rounded,
              title: 'Selected people',
              body: 'Pick a few people and send to all of them.',
              onTap: () => Navigator.pop(context, _Choice.selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Null means not available yet ("Coming soon").
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        button: available,
        label: available ? title : '$title, coming soon',
        excludeSemantics: true,
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: available
                          ? scheme.primaryContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      icon,
                      color: available
                          ? scheme.onPrimaryContainer
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (available)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    )
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          'Coming soon',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick someone nearby to chat with; people online are listed first.
class _PersonPicker extends ConsumerWidget {
  const _PersonPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final people = ref.watch(nearbyProvider).peers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text('Chat with', style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.md),
            if (people.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Nobody nearby yet. People nearby who open ${Brand.name} '
                  'appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in people)
                      ListTile(
                        leading: UserAvatar(
                          name: person.peer.name,
                          seed: person.peer.deviceId,
                          size: 44,
                        ),
                        title: Text(person.peer.name),
                        subtitle: Text(switch (person.link) {
                          LinkState.connected => 'Online',
                          LinkState.connecting => 'Connecting…',
                          LinkState.unreachable => "Can't connect",
                          LinkState.offline =>
                            'Last seen '
                                '${relativeTime(person.peer.lastSeen, clock.now())}',
                        }),
                        onTap: () =>
                            Navigator.pop(context, person.peer.deviceId),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
