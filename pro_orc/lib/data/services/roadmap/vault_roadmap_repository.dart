import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/claude_tools_scanner.dart'
    show parseYamlFrontmatter;
import 'package:pro_orc/data/services/roadmap/roadmap_repository.dart';

/// Obsidian Vault tier of the roadmap fallback chain (FR-006, Wave 2).
///
/// Reads `~/N3URAL-Vault/projects/<slug>/`, following the 7-type
/// information architecture already used across the codebase (see
/// `lib/data/services/roadmap/a1_brain_roadmap_repository.dart`'s doc
/// comment and the project CLAUDE.md's "Obsidian Vault" section):
///
/// - `spec/*.md` — feature specs, one "phase" node per spec file.
/// - `plans/*.md` — wave plans, associated with the spec they implement
///   (matched by shared numeric prefix, e.g. `001-*`).
/// - `records/*.md` — ADRs / decisions, listed alongside plans.
///
/// This tier has no native milestone/phase-status distinction like local
/// `.a1/roadmap.md` does, so it models the project itself as a single
/// milestone whose phases are its numbered specs (matching the numbering
/// convention `NNN-<slug>.md` used across `spec/` and `plans/`), each
/// carrying the spec file itself plus any matching plan/record as
/// [RoadmapSpecRef]s (FR-004/FR-005 — spec-list navigation).
///
/// Pure Dart, no Flutter imports, direct file I/O (no `Process.run` needed
/// for local reads). Never throws: any missing directory or read/parse
/// error is caught and yields [RoadmapData.empty], per the project's
/// "services return empty, never throw" convention. An unresolvable/
/// mismatched slug (FR-008) is indistinguishable from "vault dir absent"
/// and is treated identically as empty.
class ObsidianVaultRoadmapRepository implements RoadmapRepository {
  ObsidianVaultRoadmapRepository({String? vaultRootPath})
    : _vaultRootPath = vaultRootPath ?? _defaultVaultRootPath();

  final String _vaultRootPath;

  static String _defaultVaultRootPath() {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, 'N3URAL-Vault');
  }

  /// Resolves Vault-sourced roadmap data for [slug]. [projectPath] is
  /// ignored — the Vault tier is addressed purely by project slug.
  @override
  Future<RoadmapResult> resolve(String slug, String projectPath) async {
    try {
      final projectDir = Directory(p.join(_vaultRootPath, 'projects', slug));
      if (!await projectDir.exists()) {
        return const RoadmapResult(
          data: RoadmapData.empty,
          source: RoadmapSource.vault,
        );
      }

      final specFiles = await _listMarkdownFiles(
        p.join(projectDir.path, 'spec'),
      );
      if (specFiles.isEmpty) {
        return const RoadmapResult(
          data: RoadmapData.empty,
          source: RoadmapSource.vault,
        );
      }

      final planFiles = await _listMarkdownFiles(
        p.join(projectDir.path, 'plans'),
      );
      final recordFiles = await _listMarkdownFiles(
        p.join(projectDir.path, 'records'),
      );

      final phases = <RoadmapPhase>[];
      for (final specFile in specFiles) {
        final phase = await _toPhase(specFile, planFiles, recordFiles);
        if (phase != null) phases.add(phase);
      }

      if (phases.isEmpty) {
        return const RoadmapResult(
          data: RoadmapData.empty,
          source: RoadmapSource.vault,
        );
      }

      final milestone = RoadmapMilestone(
        name: slug,
        status: 'unknown',
        phases: phases,
      );

      return RoadmapResult(
        data: RoadmapData(milestones: [milestone]),
        source: RoadmapSource.vault,
      );
    } catch (_) {
      // Defensive catch-all per project convention: never throw, even on
      // unexpected I/O errors (permissions, symlink loops, etc.).
      return const RoadmapResult(
        data: RoadmapData.empty,
        source: RoadmapSource.vault,
      );
    }
  }

  Future<List<File>> _listMarkdownFiles(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return const [];
    final entries = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.md'))
        .cast<File>()
        .toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  /// Builds one [RoadmapPhase] from a spec file, attaching itself plus any
  /// plan/record file that shares its numeric prefix (e.g. `001-`) as
  /// [RoadmapSpecRef]s — FR-004/FR-005 need a spec LIST per phase, even
  /// when there is exactly one entry.
  Future<RoadmapPhase?> _toPhase(
    File specFile,
    List<File> planFiles,
    List<File> recordFiles,
  ) async {
    final baseName = p.basenameWithoutExtension(specFile.path);
    final prefix = _numericPrefix(baseName);

    String? content;
    try {
      content = await specFile.readAsString();
    } catch (_) {
      return null;
    }

    final frontmatter = parseYamlFrontmatter(content);
    final title = frontmatter['title'] ?? frontmatter['name'] ?? baseName;

    final specs = <RoadmapSpecRef>[
      RoadmapSpecRef(title: title, path: specFile.path),
    ];

    if (prefix != null) {
      for (final planFile in planFiles) {
        if (_numericPrefix(p.basenameWithoutExtension(planFile.path)) ==
            prefix) {
          specs.add(
            RoadmapSpecRef(
              title: p.basenameWithoutExtension(planFile.path),
              path: planFile.path,
            ),
          );
        }
      }
      for (final recordFile in recordFiles) {
        if (_numericPrefix(p.basenameWithoutExtension(recordFile.path)) ==
            prefix) {
          specs.add(
            RoadmapSpecRef(
              title: p.basenameWithoutExtension(recordFile.path),
              path: recordFile.path,
            ),
          );
        }
      }
    }

    final status = frontmatter['status'] ?? 'unknown';

    return RoadmapPhase(name: title, status: status, specs: specs);
  }

  /// Extracts a leading numeric prefix (e.g. `001` from `001-foo-bar.md`)
  /// used to associate a spec with its wave plan / ADR records. Returns
  /// null when the filename has no such prefix.
  String? _numericPrefix(String baseName) {
    final match = RegExp(r'^(\d+)-').firstMatch(baseName);
    return match?.group(1);
  }
}
