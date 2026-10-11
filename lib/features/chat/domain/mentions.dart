/// @mentions in Everyone messages (P15.5): pure text helpers.
library;

/// The @word being typed just before [cursor], without the @; null when
/// the cursor isn't in a mention.
String? mentionQuery(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final match = RegExp(r'(?:^|\s)@([^@\s]{0,30})$')
      .firstMatch(text.substring(0, cursor));
  return match?.group(1);
}

/// [text] with the @word before [cursor] replaced by `@name `, and where
/// the cursor goes after it.
(String, int) insertMention(String text, int cursor, String name) {
  final before = text.substring(0, cursor);
  final at = before.lastIndexOf('@');
  final inserted = '@$name ';
  final next = text.substring(0, at) + inserted + text.substring(cursor);
  return (next, at + inserted.length);
}

/// Splits [text] into plain parts and `@name` parts for any of [names],
/// longest names first so "Rahim Uddin" wins over "Rahim".
List<(String, bool)> mentionParts(String text, Iterable<String> names) {
  final sorted = {
    for (final n in names)
      if (n.isNotEmpty) n,
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  if (sorted.isEmpty || !text.contains('@')) return [(text, false)];
  final pattern = RegExp(
    '@(?:${sorted.map(RegExp.escape).join('|')})',
    caseSensitive: false,
  );
  final parts = <(String, bool)>[];
  var start = 0;
  for (final m in pattern.allMatches(text)) {
    if (m.start > start) parts.add((text.substring(start, m.start), false));
    parts.add((m.group(0)!, true));
    start = m.end;
  }
  if (start < text.length) parts.add((text.substring(start), false));
  return parts;
}
