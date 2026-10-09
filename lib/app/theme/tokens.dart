import 'package:material_ui/material_ui.dart';

/// Corner radius scale (PROJECT_PLAN.md §10.3).
abstract final class AppRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 28;
  static const double xl = 40;
}

/// Spacing on a 4 dp grid.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page padding on phones.
  static const double gutter = 16;
}

/// Motion tokens: emphasised easing, 200–500 ms (PROJECT_PLAN.md §10.3).
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 500);

  static const Curve emphasized = Easing.emphasizedDecelerate;
  static const Curve standard = Easing.standard;

  /// [duration], or zero when the user turned animations off.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
