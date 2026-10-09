import 'package:characters/characters.dart';

/// Why a username was rejected (spec §5).
enum UsernameError { empty, tooShort, tooLong, invalidCharacters }

sealed class UsernameValidation {
  const UsernameValidation();
}

/// The name passed every rule; [name] is the normalised form to store and send.
final class ValidUsername extends UsernameValidation {
  const ValidUsername(this.name);

  final String name;
}

final class InvalidUsername extends UsernameValidation {
  const InvalidUsername(this.error);

  final UsernameError error;
}

/// Username rules shared by onboarding, Change name and the LAN protocol
/// (PROJECT_PLAN.md §6.4).
abstract final class Username {
  static const minLength = 2;
  static const maxLength = 30;

  static final _whitespaceRun = RegExp(r'\s+');

  // C0 and C1 control characters, plus line and paragraph separators.
  static final _forbidden = RegExp('[\u0000-\u001F\u007F-\u009F  ]');

  /// Trims the name and collapses every run of whitespace into one space.
  static String normalize(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ');

  /// Length in user-visible characters (grapheme clusters), so emoji and
  /// Bangla conjuncts count as one each.
  static int length(String name) => name.characters.length;

  static UsernameValidation validate(String raw) {
    // Line breaks are rejected before normalising, which would hide them.
    if (raw.trim().contains(_forbidden)) {
      return const InvalidUsername(UsernameError.invalidCharacters);
    }
    final name = normalize(raw);
    if (name.isEmpty) return const InvalidUsername(UsernameError.empty);
    final count = length(name);
    if (count < minLength) return const InvalidUsername(UsernameError.tooShort);
    if (count > maxLength) return const InvalidUsername(UsernameError.tooLong);
    return ValidUsername(name);
  }

  /// Comparison key: two names clash when their keys are equal.
  static String key(String name) => normalize(name).toLowerCase();

  /// Whether [a] and [b] count as the same name on the network.
  static bool same(String a, String b) => key(a) == key(b);
}
