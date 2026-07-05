import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/a1_data.dart';

/// Reads a project's a1 roadmap/phase status (M6 Wave 2), strictly read-only.
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe.
///
/// a1 is the successor to GSD; this parser mirrors the GSD checkbox logic but
/// against `.a1/` instead of `.planning/`. Defensive throughout: missing files
/// yield empty results, malformed markdown is skipped rather than thrown.
class A1Reader {
  /// Checked checkbox line: `- [x] …` (case-insensitive x).
  static final RegExp _checked =
      RegExp(r'^\s*- \[[xX]\]\s', multiLine: true);

  /// Unchecked checkbox line: `- [ ] …`.
  static final RegExp _unchecked =
      RegExp(r'^\s*- \[ \]\s', multiLine: true);

  /// Reads `.a1/roadmap.md` + `.a1/phases/*/PLAN.md` for [projectPath].
  ///
  /// Returns [A1Data.empty] when the project has no `.a1/` directory.
  Future<A1Data> read(String projectPath) async {
    try {
      final a1Dir = Directory(p.join(projectPath, '.a1'));
      if (!await a1Dir.exists()) return A1Data.empty;

      final milestones = await _readRoadmap(p.join(a1Dir.path, 'roadmap.md'));
      final phases = await _readPhases(p.join(a1Dir.path, 'phases'));

      return A1Data(milestones: milestones, phases: phases);
    } catch (e) {
      developer.log('Failed to read a1 data for $projectPath: $e', name: 'a1_reader');
      return A1Data.empty;
    }
  }

  /// Parses the milestone table from `roadmap.md`. Expects a markdown table
  /// whose first column is the milestone name and whose last column is the
  /// status. Header and separator rows are skipped.
  Future<List<A1Milestone>> _readRoadmap(String roadmapPath) async {
    final out = <A1Milestone>[];
    final file = File(roadmapPath);
    if (!await file.exists()) return out;

    String content;
    try {
      content = await file.readAsString();
    } catch (e) {
      developer.log('Failed to read $roadmapPath: $e', name: 'a1_reader');
      return out;
    }

    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|')) continue;

      // Split into cells, dropping the empty leading/trailing pipe artifacts.
      final cells = trimmed.split('|').map((c) => c.trim()).toList();
      // Remove leading empty (before first pipe) and trailing empty (after last).
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.length < 2) continue;

      final name = cells.first;
      final status = cells.last;

      // Skip separator rows (---, :---:) and the header row.
      if (RegExp(r'^:?-{2,}:?$').hasMatch(name)) continue;
      if (name.toLowerCase() == 'milestone' ||
          status.toLowerCase() == 'status') {
        continue;
      }

      out.add(A1Milestone(name: name, status: status));
    }

    return out;
  }

  /// Scans `.a1/phases/*/PLAN.md`, counting checkboxes per phase.
  Future<List<A1Phase>> _readPhases(String phasesPath) async {
    final out = <A1Phase>[];
    final dir = Directory(phasesPath);
    if (!await dir.exists()) return out;

    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is! Directory) continue;
        final planFile = File(p.join(entity.path, 'PLAN.md'));
        if (!await planFile.exists()) continue;

        int checked = 0;
        int total = 0;
        try {
          final content = await planFile.readAsString();
          checked = _checked.allMatches(content).length;
          final unchecked = _unchecked.allMatches(content).length;
          total = checked + unchecked;
        } catch (e) {
          developer.log('Failed to read ${planFile.path}: $e', name: 'a1_reader');
        }

        out.add(A1Phase(
          name: p.basename(entity.path),
          checkedTasks: checked,
          totalTasks: total,
          planPath: planFile.path,
        ));
      }
    } catch (e) {
      developer.log('Failed to list $phasesPath: $e', name: 'a1_reader');
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }
}
