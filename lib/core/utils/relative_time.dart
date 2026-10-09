/// "just now", "5 min ago", "3 h ago", "2 days ago".
String relativeTime(DateTime time, DateTime now) {
  final elapsed = now.difference(time);
  if (elapsed.inSeconds < 60) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h ago';
  final days = elapsed.inDays;
  return days == 1 ? 'yesterday' : '$days days ago';
}
