import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/features/chat/domain/chat_message.dart';

/// "8:42 PM" (or 20:42, following the phone's setting).
String timeLabel(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// "Today", "Yesterday" or a date, for day separators.
String dayLabel(BuildContext context, DateTime time, DateTime now) {
  final day = DateUtils.dateOnly(time.toLocal());
  final today = DateUtils.dateOnly(now.toLocal());
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return MaterialLocalizations.of(context).formatMediumDate(day);
}

/// Chat list time: the time today, "Yesterday", or a short date.
String listTimeLabel(BuildContext context, DateTime time, DateTime now) {
  final day = DateUtils.dateOnly(time.toLocal());
  final today = DateUtils.dateOnly(now.toLocal());
  final difference = today.difference(day).inDays;
  if (difference == 0) return timeLabel(context, time);
  if (difference == 1) return 'Yesterday';
  return MaterialLocalizations.of(context).formatShortDate(day);
}

/// Icon and spoken label for an outgoing message's status (spec §8).
(IconData, String) statusIcon(MessageStatus status) => switch (status) {
  MessageStatus.pending => (Icons.schedule_rounded, 'Waiting to send'),
  MessageStatus.sending => (Icons.schedule_rounded, 'Sending'),
  MessageStatus.sent => (Icons.done_rounded, 'Sent'),
  MessageStatus.delivered => (Icons.done_all_rounded, 'Delivered'),
  MessageStatus.read => (Icons.done_all_rounded, 'Read'),
  MessageStatus.failed => (Icons.error_outline_rounded, 'Not sent'),
  MessageStatus.received => (Icons.done_rounded, 'Received'),
};
