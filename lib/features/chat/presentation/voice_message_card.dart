import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/core/platform/voice.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/file_transfer/data/stored_files.dart';
import 'package:resqmesh/features/file_transfer/presentation/file_message_card.dart';

/// A voice message in a bubble (P15.7): play/pause, progress and length.
/// Until it has arrived, the usual file card shows its progress.
class VoiceMessageCard extends ConsumerWidget {
  const VoiceMessageCard({
    super.key,
    required this.fileId,
    required this.voiceMs,
    required this.peerName,
    required this.foreground,
  });

  final String fileId;
  final int voiceMs;
  final String peerName;
  final Color foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(storedPathProvider(fileId));
    if (path == null) {
      return FileMessageCard(
        fileId: fileId,
        peerName: peerName,
        foreground: foreground,
      );
    }
    final state = ref.watch(voicePlaybackProvider).value;
    final mine = state != null && state.path == path;
    final playing = mine && state.playing;
    final duration = mine && state.durationMs > 0 ? state.durationMs : voiceMs;
    final position = mine ? state.positionMs : 0;
    final voice = ref.read(voiceProvider);
    final theme = Theme.of(context);
    return Semantics(
      label: 'Voice message, ${voiceLength(voiceMs)}',
      child: SizedBox(
        width: 240,
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Play voice message',
              onPressed: () =>
                  unawaited(playing ? voice.pause() : voice.play(path)),
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: foreground,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xs),
                child: LinearProgressIndicator(
                  value: duration == 0 ? 0 : (position / duration).clamp(0, 1),
                  minHeight: 4,
                  color: foreground,
                  backgroundColor: foreground.withValues(alpha: 0.25),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              voiceLength(position > 0 ? position : voiceMs),
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
