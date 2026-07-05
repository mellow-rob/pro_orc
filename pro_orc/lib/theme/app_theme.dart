import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Builds the canonical n3urala1 dark ThemeData.
///
/// Registers [AppColors.dark] as a ThemeExtension so all widgets can access
/// typed color tokens via `Theme.of(context).extension<AppColors>()!`.
ThemeData buildAppTheme() => _buildTheme(AppColors.dark, Brightness.dark);

/// Builds the light theme variant (v2.2 "Design-Refresh heller").
///
/// Same glassmorphism structure as the dark theme, but on warm off-white
/// surfaces. Registers [AppColors.light] as a ThemeExtension.
ThemeData buildAppLightTheme() => _buildTheme(AppColors.light, Brightness.light);

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();

  return base.copyWith(
    scaffoldBackgroundColor: colors.bgBase,
    colorScheme: ColorScheme(
      brightness: brightness,
      surface: colors.bgSurf,
      primary: colors.cyan,
      secondary: colors.fuch,
      onSurface: colors.textPri,
      onPrimary: brightness == Brightness.dark ? colors.bgBase : Colors.white,
      onSecondary: brightness == Brightness.dark ? colors.bgBase : Colors.white,
      error: const Color(0xFFDC2626),
      onError: Colors.white,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colors.cyan.withValues(alpha: 0.13),
      selectedIconTheme: IconThemeData(color: colors.cyan),
      unselectedIconTheme: IconThemeData(color: colors.textDim),
      selectedLabelTextStyle: TextStyle(
        color: colors.cyan,
        fontSize: 11,
        letterSpacing: 0.5,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: colors.textDim,
        fontSize: 11,
      ),
    ),
    extensions: [colors],
  );
}
