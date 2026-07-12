import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/theme/app_theme.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  group('buildAppTheme (dark)', () {
    test('has dark brightness and registers AppColors.dark', () {
      final theme = buildAppTheme();

      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.extension<AppColors>(), equals(AppColors.dark));
    });
  });

  group('buildAppLightTheme (light)', () {
    test('has light brightness and registers AppColors.light', () {
      final theme = buildAppLightTheme();

      expect(theme.brightness, equals(Brightness.light));
      expect(theme.extension<AppColors>(), equals(AppColors.light));
    });

    test('uses warm off-white background, not stark white', () {
      // Guards against regressing to plain white — the design calls for a
      // warm off-white/grey base, not Colors.white.
      expect(AppColors.light.bgBase, isNot(equals(Colors.white)));
    });
  });

  group('AppColors.light vs AppColors.dark', () {
    test(
      'share the same accent hues conceptually but different exact tones',
      () {
        // Different tones are expected (light-mode accents are darkened for
        // contrast), but both themes must define all tokens (no nulls, checked
        // implicitly by using `const` constructors) and must differ from each
        // other so the toggle is visibly meaningful.
        expect(AppColors.light.bgBase, isNot(equals(AppColors.dark.bgBase)));
        expect(AppColors.light.textPri, isNot(equals(AppColors.dark.textPri)));
      },
    );
  });
}
