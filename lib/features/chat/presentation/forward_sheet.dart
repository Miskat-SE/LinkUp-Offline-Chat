import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// Where to forward a message (P15.3): everyone online, people, or both.
typedef ForwardTarget = ({Map<String, String> people, bool everyone});

Future<ForwardTarget?> showForwardSheet(BuildContext context) =>
    showModalBottomSheet<ForwardTarget>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ForwardSheet(),
    );

class _ForwardSheet extends ConsumerStatefulWidget {
  const _ForwardSheet();

  @override
  ConsumerState<_ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends ConsumerState<_ForwardSheet> {
  final Set<String> _people = {};
  bool _everyone = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peers = ref.watch(nearbyProvider).peers;
    final online = peers.where((p) => p.link == LinkState.connected).length;
    final chosen = _people.length + (_everyone ? 1 : 0);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text('Forward to', style: theme.textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  CheckboxListTile(
                    value: _everyone,
                    onChanged: online == 0
                        ? null
                        : (on) => setState(() => _everyone = on ?? false),
                    secondary: CircleAvatar(
                      backgroundColor: theme.colorScheme.tertiaryContainer,
                      child: Icon(
                        Icons.campaign_rounded,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    title: const Text('Everyone nearby'),
                    subtitle: Text(
                      online == 0 ? 'Nobody online' : '$online online now',
                    ),
                  ),
                  for (final p in peers)
                    CheckboxListTile(
                      value: _people.contains(p.peer.deviceId),
                      onChanged: (on) => setState(
                        () => on ?? false
                            ? _people.add(p.peer.deviceId)
                            : _people.remove(p.peer.deviceId),
                      ),
                      secondary: UserAvatar(
                        name: p.peer.name,
                        seed: p.peer.deviceId,
                      ),
                      title: Text(p.peer.name),
                      subtitle: Text(
                        p.link == LinkState.connected
                            ? 'Online'
                            : 'Offline · gets it later',
                      ),
                    ),
                  if (peers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'Nobody nearby yet. People nearby who open '
                        '${Brand.name} appear here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: FilledButton.icon(
                onPressed: chosen == 0
                    ? null
                    : () => Navigator.pop<ForwardTarget>(context, (
                        people: {
                          for (final p in peers)
                            if (_people.contains(p.peer.deviceId))
                              p.peer.deviceId: p.peer.name,
                        },
                        everyone: _everyone,
                      )),
                icon: const Icon(Icons.shortcut_rounded),
                label: Text(chosen <= 1 ? 'Forward' : 'Forward to $chosen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
