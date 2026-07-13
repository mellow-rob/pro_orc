import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/learning_data.dart';

/// Reads the a1 learning loop, strictly read-only (M6 Wave 1).
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe.
///
/// Two sources (AD-2):
///   1. Vault `pattern/a1-learnings/`: per-skill retro files + `patterns.md`.
///   2. Per-project `.a1/phases/*/observations.jsonl`.
///
/// Defensive throughout: a missing vault yields an empty section (never an
/// error, AD-1), malformed markdown/JSONL lines are skipped rather than thrown.
class LearningReader {
  /// Absolute path to the Obsidian vault root. Defaults to `$HOME/N3URAL-Vault`.
  final String vaultDir;

  LearningReader({String? vaultDirOverride})
    : vaultDir =
          vaultDirOverride ??
          p.join(Platform.environment['HOME'] ?? '', 'N3URAL-Vault');

  /// Sub-path of the learnings folder relative to the vault root.
  static const _learningsRelPath = 'pattern/a1-learnings';

  /// A retro entry is marked either by a `date:` frontmatter line or the
  /// `✅ Was gut war` retro marker. We count the union defensively so both the
  /// framework's YAML-block format and the plain-marker format are recognised.
  static final RegExp _retroMarker = RegExp(
    r'^(?:date:\s*\d{4}-\d{2}-\d{2}|✅\s*Was gut war)',
    multiLine: true,
  );

  /// Files under the learnings folder that are indexes/synthesis, not per-skill
  /// retro logs. Excluded from [SkillRetro] cards.
  static const _nonSkillFiles = {'patterns.md', 'index.md'};

  /// Reads the full learning-loop state for the given [projectPaths].
  ///
  /// [projectPaths] are absolute project directories to scan for
  /// `.a1/phases/*/observations.jsonl`. Pass an empty list to read only the
  /// vault-side learnings.
  Future<LearningData> read(List<String> projectPaths) async {
    try {
      final learningsRoot = Directory(p.join(vaultDir, _learningsRelPath));
      final rootExists = await learningsRoot.exists();

      final retros = <SkillRetro>[];
      final clusters = <String>[];
      DateTime? patternsModified;
      String? patternsPath;

      if (rootExists) {
        final patternsFile = File(p.join(learningsRoot.path, 'patterns.md'));
        if (await patternsFile.exists()) {
          patternsPath = patternsFile.path;
          try {
            patternsModified = (await patternsFile.stat()).modified;
            clusters.addAll(
              _extractClusters(await patternsFile.readAsString()),
            );
          } catch (e) {
            developer.log(
              'Failed to read patterns.md: $e',
              name: 'learning_reader',
            );
          }
        }

        retros.addAll(await _readSkillRetros(learningsRoot));
      }

      final observations = await _readObservations(projectPaths);

      final sinceSynthesis = _countRetrosSince(retros, patternsModified);

      return LearningData(
        retrosPerSkill: retros,
        patternClusters: clusters,
        observations: observations,
        totalSinceLastSynthesis: sinceSynthesis,
        learningsRootPath: rootExists ? learningsRoot.path : null,
        patternsFilePath: patternsPath,
      );
    } catch (e) {
      developer.log(
        'Failed to read learning loop: $e',
        name: 'learning_reader',
      );
      return LearningData.empty;
    }
  }

  /// Reads every `*.md` retro file (excluding indexes) under [learningsRoot].
  Future<List<SkillRetro>> _readSkillRetros(Directory learningsRoot) async {
    final out = <SkillRetro>[];
    try {
      await for (final entity in learningsRoot.list(
        recursive: false,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.endsWith('.md')) continue;
        if (_nonSkillFiles.contains(name)) continue;

        int count = 0;
        DateTime? modified;
        try {
          final content = await entity.readAsString();
          count = _retroMarker.allMatches(content).length;
          modified = (await entity.stat()).modified;
        } catch (e) {
          developer.log(
            'Failed to read retro ${entity.path}: $e',
            name: 'learning_reader',
          );
        }

        out.add(
          SkillRetro(
            skill: name.substring(0, name.length - 3), // strip ".md"
            retroCount: count,
            absolutePath: entity.path,
            lastModified: modified,
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to list retros: $e', name: 'learning_reader');
    }
    out.sort((a, b) => a.skill.compareTo(b.skill));
    return out;
  }

  /// Extracts pattern-cluster titles from `patterns.md`:
  ///   - rows of the `## Applied` markdown table (first column = pattern name),
  ///   - `### … Synthese`/`## … Cluster` section headings.
  ///
  /// Deduplicated, order-preserving.
  List<String> _extractClusters(String content) {
    final seen = <String>{};
    final out = <String>[];

    void add(String? raw) {
      if (raw == null) return;
      final title = raw.replaceAll('*', '').trim();
      if (title.isEmpty) return;
      if (seen.add(title)) out.add(title);
    }

    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();

      // Table rows: | pattern | × | file | synthese |
      if (trimmed.startsWith('|') && trimmed.contains('|', 1)) {
        final cells = trimmed.split('|').map((c) => c.trim()).toList();
        // cells[0] is empty (leading pipe); the pattern name is cells[1].
        if (cells.length >= 2) {
          final first = cells[1].replaceAll('*', '').trim();
          // Skip header/separator rows.
          if (first.isNotEmpty &&
              first.toLowerCase() != 'pattern' &&
              !RegExp(r'^:?-{2,}:?$').hasMatch(first)) {
            add(first);
          }
        }
        continue;
      }

      // Synthesis / cluster section headings.
      if (trimmed.startsWith('### ') || trimmed.startsWith('## ')) {
        final heading = trimmed.replaceFirst(RegExp(r'^#{2,3}\s+'), '');
        if (RegExp(
          r'Synthese|Cluster',
          caseSensitive: false,
        ).hasMatch(heading)) {
          add(heading);
        }
      }
    }

    return out;
  }

  /// Counts retro entries modified after [patternsModified]. Since retro files
  /// aggregate multiple entries but expose only one file mtime, this is a
  /// per-file heuristic: a file touched after the last synthesis contributes
  /// its whole entry count; older files contribute nothing. When there is no
  /// `patterns.md` at all, every retro counts (nothing has been synthesised).
  int _countRetrosSince(List<SkillRetro> retros, DateTime? patternsModified) {
    var total = 0;
    for (final r in retros) {
      if (patternsModified == null) {
        total += r.retroCount;
      } else if (r.lastModified != null &&
          r.lastModified!.isAfter(patternsModified)) {
        total += r.retroCount;
      }
    }
    return total;
  }

  /// Scans each project for `.a1/phases/*/observations.jsonl`, counting valid
  /// JSON lines and tracking the newest timestamp.
  Future<List<ProjectObservations>> _readObservations(
    List<String> projectPaths,
  ) async {
    final out = <ProjectObservations>[];

    for (final projectPath in projectPaths) {
      final phasesDir = Directory(p.join(projectPath, '.a1', 'phases'));
      if (!await phasesDir.exists()) continue;

      var count = 0;
      DateTime? latest;

      try {
        await for (final entity in phasesDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          if (p.basename(entity.path) != 'observations.jsonl') continue;

          try {
            final lines = const LineSplitter().convert(
              await entity.readAsString(),
            );
            for (final line in lines) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) continue;
              final Object? decoded;
              try {
                decoded = jsonDecode(trimmed);
              } catch (_) {
                continue; // skip malformed line, never throw (AD-2)
              }
              if (decoded is! Map) continue;
              count++;
              final ts = _timestampOf(decoded);
              if (ts != null && (latest == null || ts.isAfter(latest))) {
                latest = ts;
              }
            }
          } catch (e) {
            developer.log(
              'Failed to read ${entity.path}: $e',
              name: 'learning_reader',
            );
          }
        }
      } catch (e) {
        developer.log('Failed to list $phasesDir: $e', name: 'learning_reader');
      }

      if (count > 0) {
        out.add(
          ProjectObservations(
            project: p.basename(projectPath),
            projectPath: projectPath,
            observationCount: count,
            lastObservation: latest,
          ),
        );
      }
    }

    out.sort((a, b) => a.project.compareTo(b.project));
    return out;
  }

  /// Extracts a timestamp from an observation map, trying common field names.
  DateTime? _timestampOf(Map<dynamic, dynamic> obs) {
    for (final key in const ['ts', 'timestamp', 'time', 'date']) {
      final raw = obs[key];
      if (raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
