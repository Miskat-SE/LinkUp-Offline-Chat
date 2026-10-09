import 'package:material_ui/material_ui.dart';
import 'package:resqmesh/app/theme/tokens.dart';

/// Material 3 theme with expressive styling (ADR-0016): the official
/// `material_ui` components, the Expressive variant where the package offers
/// it, and our own shape, type and motion tokens for the rest.
abstract final class AppTheme {
  /// Brand colour used when the phone has no dynamic (wallpaper) colours.
  static const Color seed = Color(0xFF00696E);

  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(_scheme(Brightness.light, dynamicScheme));

  static ThemeData dark([ColorScheme? dynamicScheme]) =>
      _build(_scheme(Brightness.dark, dynamicScheme));

  /// Rebuilds the full set of Material 3 colour roles from the wallpaper's
  /// primary colour, so surface-container roles are always present.
  static ColorScheme _scheme(Brightness brightness, ColorScheme? dynamic) =>
      ColorScheme.fromSeed(
        seedColor: dynamic?.primary ?? seed,
        brightness: brightness,
      );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme);
    final text = _expressiveText(base.textTheme);
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
    );
    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
      ),
      iconButtonTheme: const IconButtonThemeData(
        variant: StyleVariant.material3Expressive,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: roundedMd,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: roundedLg,
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        shape: roundedMd,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: text.titleMedium?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      dialogTheme: DialogThemeData(shape: roundedLg),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: _AndroidTransitions()},
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: roundedMd,
      ),
    );
  }

  /// Material 3 type scale with heavier display, headline and title weights
  /// for the expressive look.
  static TextTheme _expressiveText(TextTheme base) => base.copyWith(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w500),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w500),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w500),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}

/// Android's own page transition (with predictive back), or none at all
/// when the user turned animations off (*Remove animations*, §10.3).
final class _AndroidTransitions extends PredictiveBackPageTransitionsBuilder {
  const _AndroidTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : super.buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) =>
          MediaQuery.disableAnimationsOf(context)
          ? child
          : super.delegatedTransition?.call(
              context,
              animation,
              secondaryAnimation,
              allowSnapshotting,
              child,
            );
}
