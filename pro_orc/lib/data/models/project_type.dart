import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/theme/n3_colors.dart';

/// Project type classification for tab routing.
enum ProjectType {
  code,
  research;

  /// Parses a string to [ProjectType], returning null for unknown values.
  static ProjectType? fromString(String? value) {
    if (value == null) return null;
    return switch (value) {
      'code' => ProjectType.code,
      'research' => ProjectType.research,
      _ => null,
    };
  }
}

/// Single source of truth for [ProjectType] → visual/UI mapping, replacing
/// inline ternaries that were duplicated across project cards/rows.
extension ProjectTypeVisuals on ProjectType {
  /// Accent color: fuchsia for research, cyan for code (and any future
  /// non-research type, matching the prior `== research ? fuch : cyan`
  /// ternary default).
  Color accent(AppColors colors) =>
      this == ProjectType.research ? colors.fuch : colors.cyan;

  /// Icon: beaker for research, code-brackets otherwise.
  IconData get icon => this == ProjectType.research
      ? LucideIcons.beaker100
      : LucideIcons.codeXml100;

  /// The type a project moves to via the context menu's "move" action —
  /// the opposite of the current type.
  ProjectType get moveTarget =>
      this == ProjectType.code ? ProjectType.research : ProjectType.code;
}
