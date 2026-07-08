import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders a spec's full Markdown content read from [RoadmapSpecRef.path]
/// (FR-005). Read-only, no editing affordance.
///
/// Any read/parse failure (missing file, malformed frontmatter, broken
/// content) is caught and shown as a fallback message instead of crashing
/// the panel (FR-009) — consistent with the project's "services never
/// throw" convention.
class SpecViewer extends StatelessWidget {
  const SpecViewer({super.key, required this.spec, required this.colors});

  final RoadmapSpecRef spec;
  final AppColors colors;

  String? _readContent() {
    try {
      final file = File(spec.path);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      return content.trim().isEmpty ? null : content;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _readContent();
    if (content == null) {
      return Center(
        child: Text(
          'Spec konnte nicht angezeigt werden',
          style: TextStyle(color: colors.textDim, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      child: SelectableText(
        content,
        style: TextStyle(
          color: colors.textPri,
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.5,
        ),
      ),
    );
  }
}
