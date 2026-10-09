import 'dart:convert';

import 'package:characters/characters.dart';

/// Makes a file name from another device safe to show and to export
/// (spec §28, ADR-0014). Files are stored under our own IDs, so a name is
/// never used as a path inside the app; this guards display, Share and
/// Save to Downloads.
abstract final class FileNameSanitizer {
  static const fallback = 'file';
  static const maxBytes = 255;

  // Control characters, and bidirectional overrides that can disguise an
  // extension ("photo<RLO>gpj.exe" shows as "photoexe.jpg").
  static final _invisible = RegExp(
    '[\\u0000-\\u001F\\u007F-\\u009F\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]',
  );
  static final _reserved = RegExp(r'[<>:"/\\|?*]');
  static final _windowsDevice = RegExp(
    r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
    caseSensitive: false,
  );

  static String sanitize(String name) {
    // Only the last path segment counts: "../../x" becomes "x".
    var result = name.split(RegExp(r'[/\\]')).last;
    result = result.replaceAll(_invisible, '');
    result = result.replaceAll(_reserved, '_');
    // No hidden files, no names ending in dots or spaces.
    result = result.trim().replaceAll(RegExp(r'^[.\s]+'), '');
    result = result.replaceAll(RegExp(r'[.\s]+$'), '');
    if (result.isEmpty) return fallback;
    if (_windowsDevice.hasMatch(result)) result = '_$result';
    return _truncate(result);
  }

  /// Cuts the name to [maxBytes] of UTF-8 on a character boundary, keeping
  /// a short extension.
  static String _truncate(String name) {
    if (utf8.encode(name).length <= maxBytes) return name;
    final dot = name.lastIndexOf('.');
    final extension = dot > 0 && name.length - dot <= 16
        ? name.substring(dot)
        : '';
    final base = extension.isEmpty ? name : name.substring(0, dot);
    final budget = maxBytes - utf8.encode(extension).length;
    final kept = StringBuffer();
    var used = 0;
    for (final character in base.characters) {
      final size = utf8.encode(character).length;
      if (used + size > budget) break;
      kept.write(character);
      used += size;
    }
    final cut = kept.toString().trimRight();
    return cut.isEmpty ? fallback + extension : cut + extension;
  }
}
