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
    this.repliedToAuthor = '',
    this.onTapQuote,
    this.highlighted = false,
    this.peerName = '',
    this.onTapFailed,
    this.attachment,
    this.senderLabel,
    this.delivery,
    this.onTapDelivery,
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
  final String repliedToAuthor;

  /// Tapping the quote shows the original message.
  final VoidCallback? onTapQuote;

  /// Briefly tinted after jumping to it from a quote.
  final bool highlighted;
  final String peerName;

  /// File messages: the file card, drawn in the bubble's text colour.
  final Widget Function(Color foreground)? attachment;

  /// Everyone thread, incoming: who wrote it.
  final String? senderLabel;

  /// Everyone thread, outgoing: how far it got with each person.
  final DeliverySummary? delivery;
  final VoidCallback? onTapDelivery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mine = message.isOutgoing;
    final delivery = this.delivery;
    final status = delivery?.overall ?? message.status;
    final failed = status == MessageStatus.failed;
    final background = highlighted
        ? (mine ? scheme.primaryFixedDim : scheme.secondaryContainer)
        : (mine ? scheme.primary : scheme.surfaceContainerHigh);
    final foreground = mine ? scheme.onPrimary : scheme.onSurface;
    const big = Radius.circular(22);
    const small = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: !mine && groupedWithPrevious ? small : big,
      bottomLeft: !mine && groupedWithNext ? small : big,
      topRight: mine && groupedWithPrevious ? small : big,
      bottomRight: mine && groupedWithNext ? small : big,
    );
    final (icon, iconText) = statusIcon(status);
    final statusText = delivery?.label ?? iconText;
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
              '${mine ? 'You' : senderLabel ?? peerName}: '
              '${message.isDeleted
                  ? message.body
                  : message.isFile
                  ? 'file'
                  : message.text}. $time'
              '${mine ? '. $statusText' : ''}'
              '${(delivery?.seen ?? 0) > 0 ? '. Seen by ${delivery!.seen}' : ''}',
          // A file card keeps its own buttons reachable.
          excludeSemantics: !message.isFile,
          child: Material(
            color: failed ? scheme.errorContainer : background,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onLongPress: onLongPress,
              onTap: delivery != null
                  ? onTapDelivery
                  : (failed ? onTapFailed : null),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (senderLabel != null) ...[
                      Text(
                        senderLabel!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (repliedTo != null)
                      GestureDetector(
                        onTap: onTapQuote,
                        child: _Quote(
                          message: repliedTo!,
                          author: repliedToAuthor,
                          color: failed ? scheme.onErrorContainer : foreground,
                        ),
                      ),
                    if (message.isDeleted)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 16,
                            color: foreground.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message.body,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: foreground.withValues(alpha: 0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (message.isFile && attachment != null)
                      attachment!(failed ? scheme.onErrorContainer : foreground)
                    else
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
                        Flexible(
                          child: Text(
                            delivery != null
                                ? '$time · ${delivery.label}'
                                : (failed ? 'Not sent · Tap to retry' : time),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color:
                                  (failed
                                          ? scheme.onErrorContainer
                                          : foreground)
                                      .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                        if (delivery != null && delivery.seen > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: foreground.withValues(alpha: 0.75),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            compactCount(delivery.seen),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                        if (mine && !failed && delivery == null) ...[
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
            message.body,
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
