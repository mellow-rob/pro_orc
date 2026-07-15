import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/vision_data.dart';

/// Reads a project's optional `docs/product/VISION.md` (FR-003), the vision
/// statement + pillars file proposed by the specforge handoff doc
/// `docs/product/HANDOFF-vision-and-gate-extension.md` (Proposal 1).
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe. Mirrors
/// `A1Reader`'s defensive contract: a missing file, an unreadable file, or a
/// file with no usable lead paragraph all yield `null` rather than throwing
/// or returning a half-populated model — "no vision data" is the single
/// signal `ProjectDetailPanel` needs to hide the Vision tab entirely.
class VisionReader {
  /// Matches a `## Pillars` bullet: `- **<name>** — <description>`. The
  /// separator accepts a plain hyphen, en-dash, or em-dash (authors may type
  /// any of the three), with optional surrounding whitespace.
  static final RegExp _pillarLine = RegExp(
    r'^-\s*\*\*(.+?)\*\*\s*[-–—]\s*(.+)$',
  );

  /// Reads and parses `docs/product/VISION.md` for [projectPath].
  ///
  /// Returns `null` when the file is absent, empty, unreadable, or has no
  /// parsable lead paragraph.
  Future<VisionData?> read(String projectPath) async {
    try {
      final file = File(p.join(projectPath, 'docs', 'product', 'VISION.md'));
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      return _parse(content);
    } catch (e) {
      developer.log(
        'Failed to read VISION.md for $projectPath: $e',
        name: 'vision_reader',
      );
      return null;
    }
  }

  VisionData? _parse(String content) {
    final lines = const LineSplitter().convert(content);
    final body = _stripFrontmatter(lines);

    String? title;
    String? lead;
    final pillars = <VisionPillar>[];

    var i = 0;
    while (i < body.length) {
      final line = body[i].trim();

      if (line.isEmpty) {
        i++;
        continue;
      }

      if (line.startsWith('## Pillars')) {
        i++;
        while (i < body.length) {
          final pillarCandidate = body[i].trim();
          if (pillarCandidate.isNotEmpty) {
            final match = _pillarLine.firstMatch(pillarCandidate);
            if (match != null) {
              pillars.add(
                VisionPillar(
                  name: match.group(1)!.trim(),
                  description: match.group(2)!.trim(),
                ),
              );
            }
          }
          i++;
        }
        continue;
      }

      if (line.startsWith('# ')) {
        title ??= line.substring(2).trim();
        i++;
        continue;
      }

      if (line.startsWith('##')) {
        // Any other heading (not Pillars) — skip, we don't model it.
        i++;
        continue;
      }

      // First non-heading, non-empty line is the lead paragraph. Tolerate a
      // leading blockquote marker (`>`), which the handoff-doc format uses
      // for the vision statement.
      if (lead == null) {
        var candidate = line;
        if (candidate.startsWith('>')) {
          candidate = candidate.substring(1).trim();
        }
        if (candidate.isNotEmpty) {
          lead = candidate;
        }
      }
      i++;
    }

    if (lead == null || lead.isEmpty) return null;

    return VisionData(title: title, lead: lead, pillars: pillars);
  }

  /// Drops a leading YAML frontmatter block (`---` ... `---`) if present.
  List<String> _stripFrontmatter(List<String> lines) {
    if (lines.isEmpty || lines.first.trim() != '---') return lines;

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        return lines.sublist(i + 1);
      }
    }
    // Unterminated frontmatter block — treat the whole file as frontmatter
    // (nothing left to parse) rather than guessing.
    return const [];
  }
}
