import 'package:flutter/material.dart';

/// MOCC Typography
/// - Manrope: UI/body (lists, inventory, nutrition, points)
/// - Fraunces: display moments (recipe titles, hero headings)
class MoccTypography {
  static const String bodyFontFamily = 'Manrope';
  static const String displayFontFamily = 'Fraunces';

  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static TextStyle _manrope(TextStyle? base, {FontWeight? weight}) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: bodyFontFamily,
      fontWeight: weight ?? base?.fontWeight,
      fontFeatures: _tabularFigures,
    );
  }

  static TextStyle _fraunces(TextStyle? base, {FontWeight? weight}) {
    return (base ?? const TextStyle()).copyWith(
      fontFamily: displayFontFamily,
      fontWeight: weight ?? base?.fontWeight,
    );
  }

  static TextTheme build(TextTheme base) {
    return base.copyWith(
      // Display / hero
      displayLarge: _fraunces(base.displayLarge, weight: FontWeight.w700),
      displayMedium: _fraunces(base.displayMedium, weight: FontWeight.w700),
      displaySmall: _fraunces(base.displaySmall, weight: FontWeight.w600),

      // Headlines
      headlineLarge: _fraunces(base.headlineLarge, weight: FontWeight.w700),
      headlineMedium: _fraunces(base.headlineMedium, weight: FontWeight.w700),
      headlineSmall: _fraunces(base.headlineSmall, weight: FontWeight.w600),

      // Titles
      // Use Fraunces for big titles (recipe/page title), Manrope for the rest.
      titleLarge: _fraunces(base.titleLarge, weight: FontWeight.w600),
      titleMedium: _manrope(base.titleMedium, weight: FontWeight.w600),
      titleSmall: _manrope(base.titleSmall, weight: FontWeight.w600),

      // Body
      bodyLarge: _manrope(base.bodyLarge, weight: FontWeight.w400),
      bodyMedium: _manrope(base.bodyMedium, weight: FontWeight.w400),
      bodySmall: _manrope(base.bodySmall, weight: FontWeight.w400),

      // Labels (chips, buttons, navigation labels)
      labelLarge: _manrope(base.labelLarge, weight: FontWeight.w600),
      labelMedium: _manrope(base.labelMedium, weight: FontWeight.w500),
      labelSmall: _manrope(base.labelSmall, weight: FontWeight.w500),
    );
  }
}

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff006a61),
      surfaceTint: Color(0xff006a61),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff9ef2e6),
      onPrimaryContainer: Color(0xff005049),
      secondary: Color(0xff475d92),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffd9e2ff),
      onSecondaryContainer: Color(0xff2f4578),
      tertiary: Color(0xff8f4952),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffffdadc),
      onTertiaryContainer: Color(0xff72333b),
      error: Color(0xff8f4a4f),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdada),
      onErrorContainer: Color(0xff723338),
      surface: Color(0xfff8f9ff),
      onSurface: Color(0xff191c20),
      onSurfaceVariant: Color(0xff42474e),
      outline: Color(0xff73777f),
      outlineVariant: Color(0xffc3c7cf),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3035),
      inversePrimary: Color(0xff82d5ca),
      primaryFixed: Color(0xff9ef2e6),
      onPrimaryFixed: Color(0xff00201d),
      primaryFixedDim: Color(0xff82d5ca),
      onPrimaryFixedVariant: Color(0xff005049),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff001946),
      secondaryFixedDim: Color(0xffb1c6ff),
      onSecondaryFixedVariant: Color(0xff2f4578),
      tertiaryFixed: Color(0xffffdadc),
      onTertiaryFixed: Color(0xff3b0712),
      tertiaryFixedDim: Color(0xffffb2b9),
      onTertiaryFixedVariant: Color(0xff72333b),
      surfaceDim: Color(0xffd8dae0),
      surfaceBright: Color(0xfff8f9ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3fa),
      surfaceContainer: Color(0xffecedf4),
      surfaceContainerHigh: Color(0xffe7e8ee),
      surfaceContainerHighest: Color(0xffe1e2e8),
    );
  }

  ThemeData light() => theme(lightScheme());

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff006a61),
      surfaceTint: Color(0xff006a61),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff1c7a70),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff1d3466),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff566ca1),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff5d222b),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffa05860),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff5e2328),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffa1585d),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff8f9ff),
      onSurface: Color(0xff0e1116),
      onSurfaceVariant: Color(0xff32363d),
      outline: Color(0xff4e535a),
      outlineVariant: Color(0xff696d75),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3035),
      inversePrimary: Color(0xff82d5ca),
      primaryFixed: Color(0xff1c7a70),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff006057),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff566ca1),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff3d5387),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xffa05860),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff834049),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffc5c6cc),
      surfaceBright: Color(0xfff8f9ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff2f3fa),
      surfaceContainer: Color(0xffe7e8ee),
      surfaceContainerHigh: Color(0xffdbdce3),
      surfaceContainerHighest: Color(0xffd0d1d8),
    );
  }

  ThemeData lightMediumContrast() => theme(lightMediumContrastScheme());

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff006a61),
      surfaceTint: Color(0xff006a61),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff00534c),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff102a5c),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff31487b),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff511822),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff75353e),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff51191f),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff75353a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfff8f9ff),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff282c33),
      outlineVariant: Color(0xff454950),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3035),
      inversePrimary: Color(0xff82d5ca),
      primaryFixed: Color(0xff00534c),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff003a34),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff31487b),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff183163),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff75353e),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff591f28),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffb7b8bf),
      surfaceBright: Color(0xfff8f9ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffeff0f7),
      surfaceContainer: Color(0xffe1e2e8),
      surfaceContainerHigh: Color(0xffd3d4da),
      surfaceContainerHighest: Color(0xffc5c6cc),
    );
  }

  ThemeData lightHighContrast() => theme(lightHighContrastScheme());

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff81d5ca),
      surfaceTint: Color(0xff82d5ca),
      onPrimary: Color(0xff003732),
      primaryContainer: Color(0xff005049),
      onPrimaryContainer: Color(0xff9ef2e6),
      secondary: Color(0xffb1c6ff),
      onSecondary: Color(0xff162e60),
      secondaryContainer: Color(0xff2f4578),
      onSecondaryContainer: Color(0xffd9e2ff),
      tertiary: Color(0xffffb2b9),
      onTertiary: Color(0xff561d26),
      tertiaryContainer: Color(0xff72333b),
      onTertiaryContainer: Color(0xffffdadc),
      error: Color(0xffffb3b6),
      onError: Color(0xff561d23),
      errorContainer: Color(0xff723338),
      onErrorContainer: Color(0xffffdada),
      surface: Color(0xff111418),
      onSurface: Color(0xffe1e2e8),
      onSurfaceVariant: Color(0xffc3c7cf),
      outline: Color(0xff8d9199),
      outlineVariant: Color(0xff42474e),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2e8),
      inversePrimary: Color(0xff006a61),
      primaryFixed: Color(0xff9ef2e6),
      onPrimaryFixed: Color(0xff00201d),
      primaryFixedDim: Color(0xff82d5ca),
      onPrimaryFixedVariant: Color(0xff005049),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff001946),
      secondaryFixedDim: Color(0xffb1c6ff),
      onSecondaryFixedVariant: Color(0xff2f4578),
      tertiaryFixed: Color(0xffffdadc),
      onTertiaryFixed: Color(0xff3b0712),
      tertiaryFixedDim: Color(0xffffb2b9),
      onTertiaryFixedVariant: Color(0xff72333b),
      surfaceDim: Color(0xff111418),
      surfaceBright: Color(0xff37393e),
      surfaceContainerLowest: Color(0xff0c0e13),
      surfaceContainerLow: Color(0xff191c20),
      surfaceContainer: Color(0xff1d2024),
      surfaceContainerHigh: Color(0xff272a2f),
      surfaceContainerHighest: Color(0xff32353a),
    );
  }

  ThemeData dark() => theme(darkScheme());

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff82d5c9),
      surfaceTint: Color(0xff82d5ca),
      onPrimary: Color(0xff002b27),
      primaryContainer: Color(0xff499e94),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffd1dcff),
      onSecondary: Color(0xff072355),
      secondaryContainer: Color(0xff7a90c8),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffd1d4),
      onTertiary: Color(0xff48121c),
      tertiaryContainer: Color(0xffca7a83),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd1d2),
      onError: Color(0xff481219),
      errorContainer: Color(0xffca7a7f),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff111418),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffd9dce5),
      outline: Color(0xffaeb2ba),
      outlineVariant: Color(0xff8c9098),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2e8),
      inversePrimary: Color(0xff00514a),
      primaryFixed: Color(0xff9ef2e6),
      onPrimaryFixed: Color(0xff001512),
      primaryFixedDim: Color(0xff82d5ca),
      onPrimaryFixedVariant: Color(0xff003e38),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff000f31),
      secondaryFixedDim: Color(0xffb1c6ff),
      onSecondaryFixedVariant: Color(0xff1d3466),
      tertiaryFixed: Color(0xffffdadc),
      onTertiaryFixed: Color(0xff2c0009),
      tertiaryFixedDim: Color(0xffffb2b9),
      onTertiaryFixedVariant: Color(0xff5d222b),
      surfaceDim: Color(0xff111418),
      surfaceBright: Color(0xff42444a),
      surfaceContainerLowest: Color(0xff05070b),
      surfaceContainerLow: Color(0xff1b1e22),
      surfaceContainer: Color(0xff25282d),
      surfaceContainerHigh: Color(0xff303338),
      surfaceContainerHighest: Color(0xff3b3e43),
    );
  }

  ThemeData darkMediumContrast() => theme(darkMediumContrastScheme());

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff82d5ca),
      surfaceTint: Color(0xff82d5ca),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xff7ed1c6),
      onPrimaryContainer: Color(0xff000e0c),
      secondary: Color(0xffedefff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffacc2fd),
      onSecondaryContainer: Color(0xff000a25),
      tertiary: Color(0xffffebec),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffffacb4),
      onTertiaryContainer: Color(0xff210005),
      error: Color(0xffffeceb),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffadb1),
      onErrorContainer: Color(0xff210004),
      surface: Color(0xff111418),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xffecf0f9),
      outlineVariant: Color(0xffbfc3cb),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2e8),
      inversePrimary: Color(0xff00514a),
      primaryFixed: Color(0xff9ef2e6),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xff82d5ca),
      onPrimaryFixedVariant: Color(0xff001512),
      secondaryFixed: Color(0xffd9e2ff),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffb1c6ff),
      onSecondaryFixedVariant: Color(0xff000f31),
      tertiaryFixed: Color(0xffffdadc),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xffffb2b9),
      onTertiaryFixedVariant: Color(0xff2c0009),
      surfaceDim: Color(0xff111418),
      surfaceBright: Color(0xff4e5055),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff1d2024),
      surfaceContainer: Color(0xff2e3035),
      surfaceContainerHigh: Color(0xff393b40),
      surfaceContainerHighest: Color(0xff44474c),
    );
  }

  ThemeData darkHighContrast() => theme(darkHighContrastScheme());

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    textTheme: textTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    // Safer than colorScheme.background across Flutter versions:
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      elevation: 4,
    ),
  );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
