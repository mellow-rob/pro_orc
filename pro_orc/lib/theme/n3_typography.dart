import 'package:flutter/material.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Typography helpers for the magazine-style detail UI (FR-002), matching
/// the mockup's two custom type roles:
///
/// - `--display` — the serif headline font used for hero titles, section
///   headings, scorecard numbers, and other "editorial" display text.
/// - `.eyebrow` — the small letterspaced uppercase label above section
///   headings.
///
/// Both are exposed as static builders (not a single shared const) because
/// callers need to vary size/color per use (hero H1 vs. scorecard number vs.
/// pillar heading all use `display` at different sizes) — see mockup CSS
/// `--display`/`.eyebrow` rules in `docs/design/roadmap-redesign-mockup.html`.
class N3Typography {
  const N3Typography._();

  /// Serif display font fallback chain — mirrors the mockup's
  /// `--display: "Iowan Old Style", "Palatino Linotype", Palatino, Georgia,
  /// serif;` using macOS system fonts (no bundled font asset required).
  static const List<String> displayFontFallback = [
    'Iowan Old Style',
    'Palatino',
    'Georgia',
  ];

  /// Serif display text style (hero headlines, section H2s, scorecard
  /// numbers, pillar headings). `color` defaults to [AppColors.textPri] when
  /// omitted, matching the mockup's default `h1, h2, h3` color.
  ///
  /// Mockup values: `font-weight: 600; line-height: 1.12; letter-spacing:
  /// -.01em;` — letter-spacing is expressed in logical pixels here (Flutter
  /// has no em-relative letter-spacing), approximated per `fontSize` by the
  /// caller if a tighter fit is needed; the em-equivalent for the mockup's
  /// default sizes (~26-58px) is roughly -0.3px, applied as the default.
  static TextStyle display({
    required AppColors colors,
    required double fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: displayFontFallback.first,
      fontFamilyFallback: displayFontFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: 1.12,
      letterSpacing: letterSpacing ?? -0.01 * fontSize,
      color: color ?? colors.textPri,
    );
  }

  /// Eyebrow label style — the small letterspaced uppercase caption above
  /// section headings (e.g. "PRODUKTVISION · ROADMAP · STATUS").
  ///
  /// Mockup values: `font-weight: 800; font-size: 12px; letter-spacing:
  /// .16em; text-transform: uppercase; color: var(--cyan);`. Flutter has no
  /// `text-transform` — callers must call `.toUpperCase()` on the label text
  /// themselves. `letter-spacing: .16em` at the mockup's 12px base resolves
  /// to ~1.9 logical pixels.
  static TextStyle eyebrow({required AppColors colors, Color? color}) {
    return TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 12,
      letterSpacing: 1.9,
      color: color ?? colors.cyan,
    );
  }
}
