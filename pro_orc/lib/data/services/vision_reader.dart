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

  /// Matches a `## Links` bullet: `- [<title>](<target>)`.
  static final RegExp _linkLine = RegExp(r'^-\s*\[(.+?)\]\((.+?)\)\s*$');

  /// Matches the frontmatter `version:` key, e.g. `version: "2026.06"` or
  /// `version: 2026.06 — Closed Beta`. Surrounding single/double quotes are
  /// stripped.
  static final RegExp _versionLine = RegExp(r'^version:\s*(.+)$');

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
    final frontmatter = _extractFrontmatter(lines);
    final body = _stripFrontmatter(lines);

    final version = _parseVersion(frontmatter);

    String? title;
    String? lead;
    final pillars = <VisionPillar>[];
    final links = <VisionLink>[];

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

      if (line.startsWith('## Links')) {
        i++;
        while (i < body.length) {
          final linkCandidate = body[i].trim();
          if (linkCandidate.isNotEmpty) {
            final match = _linkLine.firstMatch(linkCandidate);
            if (match != null) {
              final target = match.group(2)!.trim();
              links.add(
                VisionLink(
                  title: match.group(1)!.trim(),
                  target: target,
                  isWeb:
                      target.startsWith('http://') ||
                      target.startsWith('https://'),
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
        // Any other heading (not Pillars/Links) — skip, we don't model it.
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

    return VisionData(
      title: title,
      version: version,
      lead: lead,
      pillars: pillars,
      links: links,
    );
  }

  /// Extracts the raw lines of a leading YAML frontmatter block (`---` ...
  /// `---`), excluding the delimiters. Empty when absent or unterminated.
  List<String> _extractFrontmatter(List<String> lines) {
    if (lines.isEmpty || lines.first.trim() != '---') return const [];

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        return lines.sublist(1, i);
      }
    }
    // Unterminated frontmatter block.
    return const [];
  }

  /// Parses the `version:` key out of the frontmatter lines. Surrounding
  /// single/double quotes are stripped. Returns null when absent or empty.
  String? _parseVersion(List<String> frontmatter) {
    for (final rawLine in frontmatter) {
      final match = _versionLine.firstMatch(rawLine.trim());
      if (match == null) continue;

      var value = match.group(1)!.trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1).trim();
      }
      return value.isEmpty ? null : value;
    }
    return null;
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
