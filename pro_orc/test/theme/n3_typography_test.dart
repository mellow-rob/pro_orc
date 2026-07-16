import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// FR-001 (Wave 1, spec 003): typography helpers lose all serif font
/// families ('Iowan Old Style', 'Palatino', 'Georgia') — hierarchy is
/// expressed via size/weight/color only, per mockup v2's "kein separater
/// Display-Font mehr" decision. The eyebrow style is unaffected (it never
/// carried a serif family) and stays letterspaced/uppercase/cyan.
void main() {
  const serifFamilies = ['Iowan Old Style', 'Palatino', 'Georgia'];

  group('N3Typography — FR-001 no serif font families', () {
    test('display() sets no fontFamily and no serif fontFamilyFallback', () {
      final style = N3Typography.display(colors: AppColors.dark, fontSize: 32);

      expect(style.fontFamily, isNull);
      expect(style.fontFamilyFallback, anyOf(isNull, isEmpty));
      for (final serif in serifFamilies) {
        expect(style.fontFamily, isNot(serif));
        expect(style.fontFamilyFallback ?? const [], isNot(contains(serif)));
      }
    });

    test('lead() sets no fontFamily and no serif fontFamilyFallback', () {
      final style = N3Typography.lead(colors: AppColors.dark);

      expect(style.fontFamily, isNull);
      expect(style.fontFamilyFallback, anyOf(isNull, isEmpty));
      for (final serif in serifFamilies) {
        expect(style.fontFamily, isNot(serif));
        expect(style.fontFamilyFallback ?? const [], isNot(contains(serif)));
      }
    });

    test('eyebrow() stays letterspaced/uppercase-styled and serif-free', () {
      final style = N3Typography.eyebrow(colors: AppColors.dark);

      expect(style.fontFamily, isNull);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, greaterThan(1));
      expect(style.color, AppColors.dark.cyan);
    });

    test('display() and lead() still express hierarchy via size/weight', () {
      final headline = N3Typography.display(
        colors: AppColors.dark,
        fontSize: 32,
        fontWeight: FontWeight.w800,
      );
      final lead = N3Typography.lead(colors: AppColors.dark);

      expect(headline.fontSize, 32);
      expect(lead.fontSize, 19.0);
      expect(lead.fontWeight, FontWeight.w400);
    });
  });
}
