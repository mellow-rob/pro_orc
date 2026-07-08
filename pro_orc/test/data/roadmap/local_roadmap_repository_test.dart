import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/local_roadmap_repository.dart';

Future<Directory> _createTempProject() async {
  final dir = await Directory.systemTemp.createTemp('roadmap_local_proj_');
  await Directory(p.join(dir.path, '.a1', 'phases')).create(recursive: true);
  return dir;
}

void main() {
  group('LocalRoadmapRepository', () {
    test('adapts A1Data milestones + phases into RoadmapData', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await File(p.join(project.path, '.a1', 'roadmap.md')).writeAsString('''
| Milestone | Status |
|---|---|
| M1 — Setup | done |
''');

      final phaseDir = Directory(
        p.join(project.path, '.a1', 'phases', 'M1-setup'),
      );
      await phaseDir.create(recursive: true);
      await File(
        p.join(phaseDir.path, 'PLAN.md'),
      ).writeAsString('- [x] a\n- [ ] b\n');

      final repo = LocalRoadmapRepository();
      final result = await repo.resolve('setup-slug', project.path);

      expect(result.source, RoadmapSource.local);
      expect(result.failure, isNull);
      expect(result.data.isEmpty, isFalse);
      expect(result.data.milestones.map((m) => m.name), contains('M1 — Setup'));
      expect(result.data.milestones.map((m) => m.name), contains('M1-setup'));
    });

    test('returns empty RoadmapData when project has no .a1 dir', () async {
      final dir = await Directory.systemTemp.createTemp('roadmap_local_none_');
      addTearDown(() => dir.delete(recursive: true));

      final repo = LocalRoadmapRepository();
      final result = await repo.resolve('slug', dir.path);

      expect(result.data.isEmpty, isTrue);
      expect(result.source, RoadmapSource.local);
    });

    test('never throws for a nonexistent path', () async {
      final repo = LocalRoadmapRepository();
      final result = await repo.resolve(
        'slug',
        '/definitely/does/not/exist/xyz',
      );

      expect(result.data.isEmpty, isTrue);
      expect(result.source, RoadmapSource.local);
    });
  });
}
