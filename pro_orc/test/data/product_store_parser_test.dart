import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/product_store_parser.dart';

Future<Directory> _createTempProject() async {
  final dir = await Directory.systemTemp.createTemp('product_store_proj_');
  await Directory(p.join(dir.path, 'docs', 'product')).create(recursive: true);
  return dir;
}

Future<void> _writeIndex(Directory project, Map<String, dynamic> json) async {
  final file = File(p.join(project.path, 'docs', 'product', 'index.json'));
  await file.writeAsString(jsonEncode(json));
}

const _validIndex = {
  'schema_version': 1,
  'generated': '2026-07-15T07:01:04.976Z',
  'project': {'id': 'pro-orc', 'title': 'Pro Orc', 'status': 'active'},
  'milestones': [
    {
      'id': 'm8-project-organization',
      'title': 'Project organization',
      'status': 'in-progress',
      'target': '2026-08',
    },
    {
      'id': 'm9-detail-roadmap-redesign',
      'title': 'Detail view and roadmap redesign',
      'status': 'in-progress',
      'target': null,
    },
  ],
  'features': [
    {
      'id': '002-project-organization',
      'milestone': 'm8-project-organization',
      'title': 'Project Hub',
      'status': 'done',
      'stage': 'done',
      'depends_on': <String>[],
      'started': '2026-07-12',
      'finished': '2026-07-15',
      'spec_path': 'projects/pro-orc/spec/002-project-organization.md',
      'plan_path':
          'projects/pro-orc/plans/002-project-organization-wave-plan.md',
    },
  ],
  'next': null,
  'cursor': null,
};

void main() {
  group('ProductStoreParser', () {
    test(
      'FR-008: parses a valid index.json into a populated ProductStoreData',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));
        await _writeIndex(project, _validIndex);

        final parser = ProductStoreParser();
        final result = await parser.parse(project.path);

        expect(result.isEmpty, isFalse);
        expect(result.milestones, hasLength(2));
        expect(result.milestones.first.id, 'm8-project-organization');
        expect(result.milestones.first.title, 'Project organization');
        expect(result.milestones.first.status, 'in-progress');
        expect(result.milestones.first.target, DateTime(2026, 8));
        expect(result.milestones.last.target, isNull);

        expect(result.features, hasLength(1));
        final feature = result.features.single;
        expect(feature.id, '002-project-organization');
        expect(feature.milestoneId, 'm8-project-organization');
        expect(feature.status, 'done');
        expect(feature.stage, 'done');
        expect(feature.started, DateTime(2026, 7, 12));
        expect(feature.finished, DateTime(2026, 7, 15));
        // spec_path in index.json is relative to the a1-learnings root, not
        // to `project.path` — no such file exists in this temp project, so
        // it must resolve to null rather than the unusable raw string (see
        // the dedicated resolution tests below for the positive case).
        expect(feature.specPath, isNull);
      },
    );

    test('FR-008: reads NEXT.md content alongside index.json', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));
      await _writeIndex(project, _validIndex);
      await File(
        p.join(project.path, 'docs', 'product', 'NEXT.md'),
      ).writeAsString('# NEXT.md\n\n## You are here\n\n- **m9** — foo\n');

      final parser = ProductStoreParser();
      final result = await parser.parse(project.path);

      expect(result.nextMdContent, contains('You are here'));
    });

    test('FR-008: records next feature id from index.json', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));
      await _writeIndex(project, {
        ..._validIndex,
        'next': '002-project-organization',
      });

      final parser = ProductStoreParser();
      final result = await parser.parse(project.path);

      expect(result.next, '002-project-organization');
    });

    test(
      'FR-008: detects features/<id>/feature.md existence without reading content',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));
        await _writeIndex(project, _validIndex);
        final featureDir = Directory(
          p.join(
            project.path,
            'docs',
            'product',
            'features',
            '002-project-organization',
          ),
        );
        await featureDir.create(recursive: true);
        await File(
          p.join(featureDir.path, 'feature.md'),
        ).writeAsString('---\nid: 002-project-organization\n---\nBody');

        final parser = ProductStoreParser();
        final result = await parser.parse(project.path);

        final feature = result.features.single;
        expect(feature.featureMdPath, isNotNull);
        expect(feature.featureMdPath, endsWith('feature.md'));
      },
    );

    test(
      'FR-009: malformed JSON returns ProductStoreData.empty, never throws',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));
        await File(
          p.join(project.path, 'docs', 'product', 'index.json'),
        ).writeAsString('{ this is not valid json ][');

        final parser = ProductStoreParser();
        final result = await parser.parse(project.path);

        expect(result.isEmpty, isTrue);
        expect(result.milestones, isEmpty);
      },
    );

    test(
      'FR-009: index.json missing required fields returns empty, never throws',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));
        await _writeIndex(project, {'schema_version': 1});

        final parser = ProductStoreParser();
        final result = await parser.parse(project.path);

        expect(result.isEmpty, isTrue);
      },
    );

    test(
      'FR-010: no docs/product/ directory returns empty, never throws',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'product_store_none_',
        );
        addTearDown(() => dir.delete(recursive: true));

        final parser = ProductStoreParser();
        final result = await parser.parse(dir.path);

        expect(result.isEmpty, isTrue);
      },
    );

    test('never throws for a nonexistent project path', () async {
      final parser = ProductStoreParser();
      final result = await parser.parse('/definitely/does/not/exist/xyz');

      expect(result.isEmpty, isTrue);
    });

    test('tolerates a feature whose spec_path/plan_path files are missing on '
        'disk — resolves to null rather than an unusable raw path', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));
      await _writeIndex(project, _validIndex);
      // spec_path/plan_path point at files that don't exist anywhere —
      // parser must not fail, and must not hand back the raw relative
      // string either (a relative path resolves against the process CWD,
      // not anything meaningful — see structured_spec_renderer.dart's
      // "Spec/Plan nicht verfügbar" fallback).
      final parser = ProductStoreParser();
      final result = await parser.parse(project.path);

      expect(result.isEmpty, isFalse);
      expect(result.features.single.specPath, isNull);
    });

    group('spec_path/plan_path resolution against the a1-learnings root', () {
      test(
        'resolves a repo-local .a1/learnings/<spec_path> into an absolute, '
        'existing path whose content matches what was written to disk',
        () async {
          final project = await _createTempProject();
          addTearDown(() => project.delete(recursive: true));

          const relativeSpecPath = 'projects/test-proj/spec/001-foo.md';
          const specContent = '# 001 Foo\n\nSpec body for the resolution test.';
          final specFile = File(
            p.join(project.path, '.a1', 'learnings', relativeSpecPath),
          );
          await specFile.create(recursive: true);
          await specFile.writeAsString(specContent);

          await _writeIndex(project, {
            ..._validIndex,
            'features': [
              {
                'id': '001-foo',
                'milestone': 'm8-project-organization',
                'title': 'Foo',
                'status': 'in-flight',
                'stage': 'started',
                'depends_on': <String>[],
                'started': '2026-07-12',
                'finished': null,
                'spec_path': relativeSpecPath,
                'plan_path': null,
              },
            ],
          });

          final parser = ProductStoreParser();
          final result = await parser.parse(project.path);

          final feature = result.features.single;
          expect(feature.specPath, isNotNull);
          expect(p.isAbsolute(feature.specPath!), isTrue);
          expect(File(feature.specPath!).existsSync(), isTrue);
          expect(File(feature.specPath!).readAsStringSync(), specContent);
        },
      );

      // The A1_VAULT_ROOT fallback tier (env var > repo-local miss) is not
      // covered by an isolated test here: Platform.environment is read
      // process-wide and cannot be scoped per-test without a subprocess,
      // which would be disproportionate for this code path. The repo-local
      // tier above exercises the same `_resolveStorePath` logic end-to-end
      // (existence check + p.join), and the "missing on disk" test above
      // exercises the not-found branch that the vault tier shares.
    });
  });
}
