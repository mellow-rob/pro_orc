import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/a1_reader.dart';

/// Creates a temp project with a `.a1/` directory and returns the project dir.
Future<Directory> _createTempProject() async {
  final dir = await Directory.systemTemp.createTemp('a1_proj_');
  await Directory(p.join(dir.path, '.a1', 'phases')).create(recursive: true);
  return dir;
}

Future<void> _writePhasePlan(
  Directory project,
  String phaseName,
  String plan,
) async {
  final phaseDir = Directory(p.join(project.path, '.a1', 'phases', phaseName));
  await phaseDir.create(recursive: true);
  await File(p.join(phaseDir.path, 'PLAN.md')).writeAsString(plan);
}

void main() {
  group('A1Reader — roadmap', () {
    test('parses milestone table (name + last-column status)', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await File(p.join(project.path, '.a1', 'roadmap.md')).writeAsString('''
# Roadmap

| Milestone | Inhalt | Status |
|---|---|---|
| M1 — Setup | Basis | done (2026-07-05) |
| M6 — Learning | Retros | in_progress |
| M7 — Optional | Kosten | pending |
''');

      final data = await A1Reader().read(project.path);

      expect(data.milestones, hasLength(3));
      expect(data.milestones[0].name, 'M1 — Setup');
      expect(data.milestones[0].isDone, isTrue);
      expect(data.milestones[1].name, 'M6 — Learning');
      expect(data.milestones[1].isActive, isTrue);
      expect(data.milestones[2].isDone, isFalse);
      expect(data.milestones[2].isActive, isFalse);
    });

    test('skips header and separator rows', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await File(p.join(project.path, '.a1', 'roadmap.md')).writeAsString('''
| Milestone | Status |
|---|---|
| M1 | done |
''');

      final data = await A1Reader().read(project.path);
      expect(data.milestones, hasLength(1));
      expect(data.milestones.single.name, 'M1');
    });
  });

  group('A1Reader — phases', () {
    test('counts checkboxes per PLAN.md', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writePhasePlan(project, 'M6-learning', '''
## Wave 1
- [x] Task A
- [x] Task B
- [ ] Task C

## Wave 2
- [ ] Task D
''');

      final data = await A1Reader().read(project.path);

      expect(data.phases, hasLength(1));
      final phase = data.phases.single;
      expect(phase.name, 'M6-learning');
      expect(phase.checkedTasks, 2);
      expect(phase.totalTasks, 4);
      expect(phase.progress, 50);
      expect(phase.isActive, isTrue);
    });

    test(
      'activePhase is the first with unfinished tasks, sorted by name',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));

        await _writePhasePlan(project, 'M1-done', '- [x] a\n- [x] b\n');
        await _writePhasePlan(project, 'M2-active', '- [x] a\n- [ ] b\n');

        final data = await A1Reader().read(project.path);

        expect(data.phases.map((ph) => ph.name), ['M1-done', 'M2-active']);
        expect(data.activePhase?.name, 'M2-active');
      },
    );

    test('overallProgress aggregates across all phases', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writePhasePlan(project, 'p1', '- [x] a\n- [x] b\n'); // 2/2
      await _writePhasePlan(project, 'p2', '- [ ] a\n- [ ] b\n'); // 0/2

      final data = await A1Reader().read(project.path);
      // 2 checked of 4 total → 50%.
      expect(data.overallProgress, 50);
    });
  });

  group('A1Reader — missing files', () {
    test('returns empty when there is no .a1 directory', () async {
      final dir = await Directory.systemTemp.createTemp('a1_none_');
      addTearDown(() => dir.delete(recursive: true));

      final data = await A1Reader().read(dir.path);
      expect(data.isEmpty, isTrue);
    });

    test('handles .a1 without roadmap or phases gracefully', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      // .a1/phases exists but is empty; no roadmap.md.
      final data = await A1Reader().read(project.path);
      expect(data.milestones, isEmpty);
      expect(data.phases, isEmpty);
      expect(data.isEmpty, isTrue);
    });

    test('phase directory without PLAN.md is skipped', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await Directory(
        p.join(project.path, '.a1', 'phases', 'empty-phase'),
      ).create(recursive: true);

      final data = await A1Reader().read(project.path);
      expect(data.phases, isEmpty);
    });
  });
}
