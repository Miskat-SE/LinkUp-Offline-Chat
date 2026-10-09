import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';
import 'package:resqmesh/features/chat/presentation/chat_format.dart';

/// One message. Outgoing on the right in the primary colour, incoming on the
/// left. Consecutive messages from the same side are grouped with tighter
/// corners.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.groupedWithPrevious,
    required this.groupedWithNext,
    required this.onLongPress,
    this.repliedTo,
    this.repliedToIsMine = false,
    this.peerName = '',
    this.onTapFailed,
  });

  final ChatMessage message;

  /// The message above is from the same side, close in time.
  final bool groupedWithPrevious;

  /// The message below is from the same side, close in time.
  final bool groupedWithNext;
  final VoidCallback onLongPress;
  final VoidCallback? onTapFailed;

  /// The message this one replies to, if it is still on this phone.
  final ChatMessage? repliedTo;
  final bool repliedToIsMine;
  final String peerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isOutgoing;
    final failed = message.status == MessageStatus.failed;
    final background = mine ? scheme.primary : scheme.surfaceContainerHigh;
    final foreground = mine ? scheme.onPrimary : scheme.onSurface;
    const big = Radius.circular(22);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: !mine && groupedWithPrevious ? small : big,
      bottomLeft: !mine && groupedWithNext ? small : big,
      topRight: mine && groupedWithPrevious ? small : big,
      bottomRight: mine && groupedWithNext ? small : big,
    );
    final (icon, statusText) = statusIcon(message.status);
    final time = timeLabel(context, message.createdAt);

    return Padding(
      padding: EdgeInsets.only(
        top: groupedWithPrevious ? 2 : AppSpacing.sm,
        left: mine ? 56 : 0,
        right: mine ? 0 : 56,
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Semantics(
          label:
              '${mine ? 'You' : peerName}: ${message.text}. $time'
              '${mine ? '. $statusText' : ''}',
          excludeSemantics: true,
          child: Material(
            color: failed ? scheme.errorContainer : background,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onLongPress: onLongPress,
              onTap: failed ? onTapFailed : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (repliedTo != null)
                      _Quote(
                        message: repliedTo!,
                        author: repliedToIsMine ? 'You' : peerName,
                        color: failed ? scheme.onErrorContainer : foreground,
                      ),
                    Text(
                      message.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: failed ? scheme.onErrorContainer : foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          failed ? 'Not sent · Tap to retry' : time,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                (failed ? scheme.onErrorContainer : foreground)
                                    .withValues(alpha: 0.75),
                          ),
                        ),
                        if (mine && !failed) ...[
                          const SizedBox(width: 4),
                          Icon(
                            icon,
                            size: 15,
                            color: message.status == MessageStatus.read
                                ? scheme.inversePrimary
                                : foreground.withValues(alpha: 0.75),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({
    required this.message,
    required this.author,
    required this.color,
  });

  final ChatMessage message;
  final String author;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            author,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
          Text(
            message.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
