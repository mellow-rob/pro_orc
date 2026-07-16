import 'package:flutter/material.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Typography helpers for the detail UI, matching the mockup v2 type roles:
///
/// - `display` — the headline text used for hero titles, section headings,
///   scorecard numbers, and other emphasized text. Mockup v2 dropped the
///   separate serif display font ("kein separater Display-Font mehr —
///   Hierarchie ueber Groesse/Gewicht/Farbe") — hierarchy is expressed via
///   `fontSize`/`fontWeight`/`color` only, rendered in the app's standard
///   sans stack (no `fontFamily` override).
/// - `.eyebrow` — the small letterspaced uppercase label above section
///   headings.
///
/// Both are exposed as static builders (not a single shared const) because
/// callers need to vary size/color per use (hero H1 vs. scorecard number vs.
/// pillar heading all use `display` at different sizes) — see mockup CSS
/// `--body`/`.eyebrow` rules in `docs/design/roadmap-redesign-mockup-v2.html`.
class N3Typography {
  const N3Typography._();

  /// Display text style (hero headlines, section H2s, scorecard numbers,
  /// pillar headings). `color` defaults to [AppColors.textPri] when omitted,
  /// matching the mockup's default `h1, h2, h3` color. Renders in the app's
  /// standard sans font (no `fontFamily` override) — v2 dropped the serif
  /// display font entirely (FR-001).
  ///
  /// Mockup values: `font-weight: 800; line-height: 1.16; letter-spacing:
  /// -.01em;` — letter-spacing is expressed in logical pixels here (Flutter
  /// has no em-relative letter-spacing), approximated per `fontSize` by the
  /// caller if a tighter fit is needed; the em-equivalent for the mockup's
  /// default sizes (~26-58px) is roughly -0.3px, applied as the default.
  static TextStyle display({
    required AppColors colors,
    required double fontSize,
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double height = 1.16,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing ?? -0.01 * fontSize,
      color: color ?? colors.textPri,
    );
  }

  /// "Lead prose" text style — mockup `.prose.lead`: `font-size: clamp(16px,
  /// 2.2vw, 19px); line-height: 1.55;` used for a section's opening
  /// paragraph (e.g. the spec view's "Problem" section, FR-007), as distinct
  /// from [display]'s tighter headline/scorecard line-height and heavier
  /// default weight — lead prose is body text, not a heading, so it defaults
  /// to [FontWeight.w400]. Sans, no `fontFamily` override (FR-001).
  static TextStyle lead({required AppColors colors, Color? color}) {
    return display(
      colors: colors,
      fontSize: 19,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.55,
      color: color,
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
