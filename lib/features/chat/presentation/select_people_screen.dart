import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/constants/brand.dart';
import 'package:resqmesh/core/network/lan_providers.dart';
import 'package:resqmesh/core/network/nearby.dart';
import 'package:resqmesh/features/chat/data/chat_providers.dart';
import 'package:resqmesh/features/file_transfer/data/file_picker_service.dart';
import 'package:resqmesh/features/file_transfer/presentation/send_files_sheet.dart';
import 'package:resqmesh/shared/widgets/empty_state.dart';
import 'package:resqmesh/shared/widgets/user_avatar.dart';

/// Send to selected people (P7.3): pick several people, then a message or
/// files. Each person gets it in their own chat; anyone offline gets it
/// when they are back.
class SelectPeopleScreen extends ConsumerStatefulWidget {
  const SelectPeopleScreen({super.key, this.preselected});

  final String? preselected;

  @override
  ConsumerState<SelectPeopleScreen> createState() => _SelectPeopleScreenState();
}

class _SelectPeopleScreenState extends ConsumerState<SelectPeopleScreen> {
  late final Set<String> _selected = {?widget.preselected};
  final TextEditingController _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Map<String, String> _people(List<NearbyPeer> peers) => {
    for (final p in peers)
      if (_selected.contains(p.peer.deviceId)) p.peer.deviceId: p.peer.name,
  };

  Future<void> _send(List<NearbyPeer> peers, {bool files = false}) async {
    final people = _people(peers);
    if (people.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final messaging = ref.read(messagingServiceProvider);
    setState(() => _busy = true);
    try {
      if (files) {
        final picked = await ref.read(filePickerProvider).pick(onBusy: (_) {});
        if (!mounted || picked.isEmpty) return;
        final chosen = await showSendFilesSheet(
          context,
          files: picked,
          peerName: _who(people),
        );
        if (chosen == null || chosen.isEmpty) return;
        await messaging.sendToPeople(people: people, files: chosen);
      } else {
        final text = _text.text.trim();
        if (text.isEmpty) return;
        await messaging.sendToPeople(people: people, text: text);
      }
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${_who(people)}. Anyone offline gets it when they are back.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _who(Map<String, String> people) =>
      people.length == 1 ? people.values.single : '${people.length} people';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peers = ref.watch(nearbyProvider).peers;
    final count = _people(peers).length;
    final ready = count > 0 && !_busy;
    return Scaffold(
      appBar: AppBar(
        title: Text(count == 0 ? 'Select people' : '$count selected'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: peers.isEmpty
                  ? const EmptyState(
                      compact: true,
                      icon: Icons.group_add_rounded,
                      title: 'Nobody nearby yet',
                      message:
                          'People nearby who open ${Brand.name} appear here.',
                    )
                  : ListView(
                      children: [
                        for (final p in peers)
                          CheckboxListTile(
                            value: _selected.contains(p.peer.deviceId),
                            onChanged: (on) => setState(
                              () => on ?? false
                                  ? _selected.add(p.peer.deviceId)
                                  : _selected.remove(p.peer.deviceId),
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
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
            Padding(
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
                    onPressed: ready ? () => _send(peers, files: true) : null,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: count > 0,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: count == 0
                            ? 'Select people first'
                            : 'Message to $count',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: ready && _text.text.trim().isNotEmpty
                        ? () => _send(peers)
                        : null,
                    icon: const Icon(Icons.send_rounded),
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
