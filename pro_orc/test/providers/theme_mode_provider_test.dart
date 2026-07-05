import 'package:flutter/material.dart';
import 'package:test/test.dart';

import 'package:pro_orc/providers/theme_mode_provider.dart';

void main() {
  group('themeModeFromString', () {
    test('converts "light" to ThemeMode.light', () {
      expect(themeModeFromString('light'), equals(ThemeMode.light));
    });

    test('converts "system" to ThemeMode.system', () {
      expect(themeModeFromString('system'), equals(ThemeMode.system));
    });

    test('converts "dark" to ThemeMode.dark', () {
      expect(themeModeFromString('dark'), equals(ThemeMode.dark));
    });

    test('falls back to ThemeMode.dark for unknown values', () {
      expect(themeModeFromString('unknown'), equals(ThemeMode.dark));
      expect(themeModeFromString(''), equals(ThemeMode.dark));
    });
  });

  group('themeModeToString', () {
    test('converts ThemeMode.light to "light"', () {
      expect(themeModeToString(ThemeMode.light), equals('light'));
    });

    test('converts ThemeMode.system to "system"', () {
      expect(themeModeToString(ThemeMode.system), equals('system'));
    });

    test('converts ThemeMode.dark to "dark"', () {
      expect(themeModeToString(ThemeMode.dark), equals('dark'));
    });
  });

  group('round-trip', () {
    test('all ThemeMode values survive a round-trip through the DB string', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromString(themeModeToString(mode)), equals(mode));
      }
    });
  });
}
