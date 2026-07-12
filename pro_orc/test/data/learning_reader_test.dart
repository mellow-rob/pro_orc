import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/learning_reader.dart';

/// Creates `pattern/a1-learnings/` inside a fresh temp vault and returns its
/// root path. The caller writes files into it.
Future<Directory> _createTempVault() async {
  final vault = await Directory.systemTemp.createTemp('learning_vault_');
  await Directory(
    p.join(vault.path, 'pattern', 'a1-learnings'),
  ).create(recursive: true);
  return vault;
}

String _learningsDir(Directory vault) =>
    p.join(vault.path, 'pattern', 'a1-learnings');

void main() {
  group('LearningReader — vault retros', () {
    test('counts retro entries per skill via date + marker', () async {
      final vault = await _createTempVault();
      addTearDown(() => vault.delete(recursive: true));

      // Two entries: one YAML-block with date:, one bare marker.
      await File(p.join(_learningsDir(vault), 'a1-execute.md')).writeAsString(
        '''
---
date: 2026-07-04
result: pass
---
✅ Was gut war: sauberer Wave-Split.
⚠️ Was nicht passte: falsche Pfade.
---
date: 2026-07-05
result: pass
---
✅ Was gut war: ehrliche Reports.
''',
      );

      // Single entry, marker-only format.
      await File(p.join(_learningsDir(vault), 'a1-plan.md')).writeAsString('''
✅ Was gut war: Research vor Plan.
''');

      final reader = LearningReader(vaultDirOverride: vault.path);
      final data = await reader.read([]);

      final byName = {for (final r in data.retrosPerSkill) r.skill: r};
      expect(byName.keys, containsAll(['a1-execute', 'a1-plan']));
      // date: (2) and ✅ (2) markers dedup by line — union counts 4 lines total
      // in a1-execute (2 date + 2 marker).
      expect(byName['a1-execute']!.retroCount, 4);
      expect(byName['a1-plan']!.retroCount, 1);
    });

    test('excludes index.md and patterns.md from skill retros', () async {
      final vault = await _createTempVault();
      addTearDown(() => vault.delete(recursive: true));

      await File(
        p.join(_learningsDir(vault), 'index.md'),
      ).writeAsString('# Index\n');
      await File(
        p.join(_learningsDir(vault), 'patterns.md'),
      ).writeAsString('# Patterns\n');
      await File(
        p.join(_learningsDir(vault), 'a1-fix.md'),
      ).writeAsString('✅ Was gut war: x\n');

      final reader = LearningReader(vaultDirOverride: vault.path);
      final data = await reader.read([]);

      final names = data.retrosPerSkill.map((r) => r.skill).toList();
      expect(names, ['a1-fix']);
    });

    test(
      'extracts pattern clusters from table rows and synthesis headings',
      () async {
        final vault = await _createTempVault();
        addTearDown(() => vault.delete(recursive: true));

        await File(p.join(_learningsDir(vault), 'patterns.md')).writeAsString(
          '''
# Pattern-Cluster

## Applied (Threshold 3+)

| Pattern | × | Ziel-Datei | Synthese |
|---|---|---|---|
| gate_enforcement_gap | 4 | 05-implement.md | — |
| **gate_fr_token_overcount** | 5 | 04-plan.md | 2026-06-19 |

### 2026-06-19 Synthese (Agent Space)

## Monitoring (watch)
''',
        );

        final reader = LearningReader(vaultDirOverride: vault.path);
        final data = await reader.read([]);

        expect(data.patternClusters, contains('gate_enforcement_gap'));
        // Bold markers stripped.
        expect(data.patternClusters, contains('gate_fr_token_overcount'));
        expect(
          data.patternClusters,
          contains('2026-06-19 Synthese (Agent Space)'),
        );
        // Header row and separator row must not appear.
        expect(data.patternClusters, isNot(contains('Pattern')));
      },
    );
  });

  group('LearningReader — missing vault (AD-1)', () {
    test('returns empty section, never throws, when vault is absent', () async {
      final reader = LearningReader(
        vaultDirOverride: p.join(
          Directory.systemTemp.path,
          'does_not_exist_xyz',
        ),
      );
      final data = await reader.read([]);

      expect(data.isEmpty, isTrue);
      expect(data.retrosPerSkill, isEmpty);
      expect(data.learningsRootPath, isNull);
      expect(data.evolveDue, isFalse);
    });
  });

  group('LearningReader — evolve heuristic', () {
    test('counts all retros when no patterns.md exists', () async {
      final vault = await _createTempVault();
      addTearDown(() => vault.delete(recursive: true));

      await File(p.join(_learningsDir(vault), 'a1-execute.md')).writeAsString(
        '✅ Was gut war: a\n✅ Was gut war: b\n✅ Was gut war: c\n'
        '✅ Was gut war: d\n✅ Was gut war: e\n',
      );

      final reader = LearningReader(vaultDirOverride: vault.path);
      final data = await reader.read([]);

      expect(data.totalSinceLastSynthesis, 5);
      expect(data.evolveDue, isTrue); // threshold is 5
    });

    test('counts only retros newer than patterns.md', () async {
      final vault = await _createTempVault();
      addTearDown(() => vault.delete(recursive: true));

      final oldRetro = File(p.join(_learningsDir(vault), 'a1-plan.md'));
      await oldRetro.writeAsString('✅ Was gut war: alt\n');
      // Backdate the old retro well before patterns.md.
      final old = DateTime.now().subtract(const Duration(days: 10));
      await oldRetro.setLastModified(old);

      final patterns = File(p.join(_learningsDir(vault), 'patterns.md'));
      await patterns.writeAsString('# Patterns\n| Pattern |\n');
      await patterns.setLastModified(
        DateTime.now().subtract(const Duration(days: 5)),
      );

      final newRetro = File(p.join(_learningsDir(vault), 'a1-execute.md'));
      await newRetro.writeAsString('✅ Was gut war: neu\n✅ Was gut war: neu2\n');
      // newRetro keeps "now" mtime → after patterns.md.

      final reader = LearningReader(vaultDirOverride: vault.path);
      final data = await reader.read([]);

      // Only the 2 new entries count; the backdated one does not.
      expect(data.totalSinceLastSynthesis, 2);
      expect(data.evolveDue, isFalse);
    });
  });

  group('LearningReader — observations.jsonl', () {
    test('counts valid JSONL lines and tracks latest timestamp', () async {
      final vault = await _createTempVault();
      addTearDown(() => vault.delete(recursive: true));

      final project = await Directory.systemTemp.createTemp('learn_proj_');
      addTearDown(() => project.delete(recursive: true));
      final phaseDir = Directory(
        p.join(project.path, '.a1', 'phases', 'M1-p1'),
      );
      await phaseDir.create(recursive: true);

      await File(p.join(phaseDir.path, 'observations.jsonl')).writeAsString('''
{"ts": "2026-07-01T10:00:00Z", "note": "a"}
{"ts": "2026-07-03T10:00:00Z", "note": "b"}
not valid json at all
{"note": "c without ts"}
''');

      final reader = LearningReader(vaultDirOverride: vault.path);
      final data = await reader.read([project.path]);

      expect(data.observations, hasLength(1));
      final obs = data.observations.first;
      expect(obs.project, p.basename(project.path));
      // 3 valid JSON lines (2 with ts + 1 without); the malformed line skipped.
      expect(obs.observationCount, 3);
      expect(obs.lastObservation, DateTime.parse('2026-07-03T10:00:00Z'));
    });

    test(
      'skips projects without .a1/phases and malformed files gracefully',
      () async {
        final vault = await _createTempVault();
        addTearDown(() => vault.delete(recursive: true));

        final noA1 = await Directory.systemTemp.createTemp('learn_noa1_');
        addTearDown(() => noA1.delete(recursive: true));

        final reader = LearningReader(vaultDirOverride: vault.path);
        final data = await reader.read([noA1.path]);

        expect(data.observations, isEmpty);
      },
    );
  });
}
