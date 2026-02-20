import 'package:flutter/material.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Builds the canonical n3urala1 dark ThemeData.
///
/// Registers [AppColors.dark] as a ThemeExtension so all widgets can access
/// typed color tokens via `Theme.of(context).extension<AppColors>()!`.
ThemeData buildAppTheme() {
  const colors = AppColors.dark;

  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: colors.bgBase,
    colorScheme: ColorScheme.dark(
      surface: colors.bgSurf,
      primary: colors.cyan,
      secondary: colors.fuch,
      onSurface: colors.textPri,
      onPrimary: colors.bgBase,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: const Color(0x2200CDDC),
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
    extensions: const [AppColors.dark],
  );
}
