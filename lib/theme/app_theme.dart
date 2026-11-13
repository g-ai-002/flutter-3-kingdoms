import 'package:flutter/material.dart';

import '../utils/system_ui.dart';

/// 朱砂、金铜与宣纸构成的三国视觉基调。
const Color appRed = Color(0xFF8C2F24);
const Color appGold = Color(0xFFC8A15A);
const Color appInk = Color(0xFF241811);
const Color appParchment = Color(0xFFF3E7CE);
const Color appJade = Color(0xFF2F6B58);

ThemeData buildLightTheme({String? fontFamily}) {
  const scheme = ColorScheme.light(
    primary: Color(0xFF8C2F24),
    onPrimary: Color(0xFFFFF6E9),
    primaryContainer: Color(0xFFF0D6C8),
    onPrimaryContainer: Color(0xFF4A170F),
    secondary: Color(0xFF8A6A32),
    onSecondary: Color(0xFFFFF6E9),
    secondaryContainer: Color(0xFFEEDCB8),
    onSecondaryContainer: Color(0xFF3B2A0E),
    tertiary: Color(0xFF2F6B58),
    onTertiary: Color(0xFFFFF6E9),
    surface: Color(0xFFFBF3E2),
    onSurface: Color(0xFF2A1C12),
    surfaceContainerHighest: Color(0xFFF1E3C8),
    onSurfaceVariant: Color(0xFF7A6349),
    outline: Color(0xFFE0CDA9),
    outlineVariant: Color(0xFFEADCC0),
    error: Color(0xFFB3261E),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: appParchment,
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFE8A87C),
    onPrimary: Color(0xFF3A1208),
    primaryContainer: Color(0xFF5A2318),
    onPrimaryContainer: Color(0xFFF8DCD2),
    secondary: Color(0xFFD8B98A),
    onSecondary: Color(0xFF3A2A16),
    secondaryContainer: Color(0xFF4A3A20),
    onSecondaryContainer: Color(0xFFF1DDB6),
    tertiary: Color(0xFF8FBFAE),
    onTertiary: Color(0xFF0F2B22),
    surface: Color(0xFF221A12),
    onSurface: Color(0xFFF1E4CE),
    surfaceContainerHighest: Color(0xFF2E2418),
    onSurfaceVariant: Color(0xFFB9A583),
    outline: Color(0xFF4A3B29),
    outlineVariant: Color(0xFF3A2E21),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF3A0A08),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: scheme,
    scaffoldColor: const Color(0xFF171009),
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  String? fontFamily,
}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
  );
  final textTheme = base.textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
    fontFamily: fontFamily,
  );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 4,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: systemOverlayStyleFor(scaffoldColor),
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      showCheckmark: false,
      side: BorderSide(color: colorScheme.outline),
      shape: const StadiumBorder(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.6),
      thickness: 0.6,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
