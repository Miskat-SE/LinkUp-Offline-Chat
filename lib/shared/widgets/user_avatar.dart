import 'package:material_ui/material_ui.dart';

/// Initials on a tonal circle. The colour is picked from [seed] (a device ID),
/// so the same person keeps the same colour.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.size = 48,
  });

  final String name;
  final String seed;
  final double size;

  /// Up to two initials, one from each of the first two words.
  static String initialsOf(String name) {
    final words = name.split(' ').where((word) => word.isNotEmpty).take(2);
    final initials = words.map((word) => word.characters.first).join();
    return initials.isEmpty ? '?' : initials.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pairs = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ];
    // Stable across runs and app versions, unlike String.hashCode.
    final index = seed.codeUnits.fold(0, (sum, unit) => sum + unit) % 3;
    final (background, foreground) = pairs[index];
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: background,
        foregroundColor: foreground,
        child: Text(
          initialsOf(name),
          style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
