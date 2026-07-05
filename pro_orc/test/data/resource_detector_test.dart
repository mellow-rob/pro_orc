import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/resource_detector.dart';

void main() {
  group('detectExternalResources', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('resource_detector_test_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    ProjectModel projectWithMdFiles(List<MdFileInfo> mdFiles) {
      return ProjectModel(
        folderId: p.basename(tmp.path),
        displayName: 'Test Project',
        path: tmp.path,
        projectType: ProjectType.code,
        mdFiles: mdFiles,
      );
    }

    test('finds a Figma URL from a scanned md file', () async {
      final file = File(p.join(tmp.path, 'STATE.md'));
      await file.writeAsString(
        'Design lives at https://figma.com/file/abc123 for reference.',
      );

      final project = projectWithMdFiles([
        MdFileInfo(name: 'STATE.md', relativePath: 'STATE.md', path: file.path),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, hasLength(1));
      expect(resources.first.type, ExternalResourceType.figma);
      expect(resources.first.uri, equals('https://figma.com/file/abc123'));
    });

    test('does not re-scan the filesystem — relies solely on project.mdFiles', () async {
      // A .md file exists on disk but is NOT included in project.mdFiles.
      final file = File(p.join(tmp.path, 'IGNORED.md'));
      await file.writeAsString('https://figma.com/file/should-not-be-found');

      final project = projectWithMdFiles(const []);

      final resources = await detectExternalResources(project);

      expect(resources, isEmpty);
    });

    test('skips noise domains like localhost', () async {
      final file = File(p.join(tmp.path, 'STATE.md'));
      await file.writeAsString('See http://localhost:3000/dashboard for dev.');

      final project = projectWithMdFiles([
        MdFileInfo(name: 'STATE.md', relativePath: 'STATE.md', path: file.path),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, isEmpty);
    });

    test('returns empty list when project has no mdFiles', () async {
      final project = projectWithMdFiles(const []);

      final resources = await detectExternalResources(project);

      expect(resources, isEmpty);
    });
  });
}
