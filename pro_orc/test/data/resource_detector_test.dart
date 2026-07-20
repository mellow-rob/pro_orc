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

    test(
      'does not re-scan the filesystem — relies solely on project.mdFiles',
      () async {
        // A .md file exists on disk but is NOT included in project.mdFiles.
        final file = File(p.join(tmp.path, 'IGNORED.md'));
        await file.writeAsString('https://figma.com/file/should-not-be-found');

        final project = projectWithMdFiles(const []);

        final resources = await detectExternalResources(project);

        expect(resources, isEmpty);
      },
    );

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

    test(
      'classifies a vercel.com dashboard URL as ExternalResourceType.vercel',
      () async {
        final file = File(p.join(tmp.path, 'STATE.md'));
        await file.writeAsString(
          'Deployed at https://vercel.com/my-scope/my-project for prod.',
        );

        final project = projectWithMdFiles([
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ]);

        final resources = await detectExternalResources(project);

        expect(resources, hasLength(1));
        expect(resources.first.type, ExternalResourceType.vercel);
        expect(
          resources.first.uri,
          equals('https://vercel.com/my-scope/my-project'),
        );
      },
    );

    test(
      'classifies a *.vercel.app deployment URL as ExternalResourceType.other '
      '(no derivable project name, distinct from ExternalResourceType.vercel)',
      () async {
        final file = File(p.join(tmp.path, 'STATE.md'));
        await file.writeAsString(
          'Preview at https://my-app-abc123xyz.vercel.app for QA.',
        );

        final project = projectWithMdFiles([
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ]);

        final resources = await detectExternalResources(project);

        expect(resources, hasLength(1));
        expect(resources.first.type, ExternalResourceType.other);
        expect(resources.first.type, isNot(ExternalResourceType.vercel));
      },
    );

    test('does not list generic documentation domains (e.g. nextjs.org) as '
        'resources — a create-next-app README with many doc links must not '
        'flood the dialog with non-resource entries '
        '(2026-07-20-delete-dialog-resource-over-detection)', () async {
      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString('''
# My App

This is a [Next.js](https://nextjs.org/) project bootstrapped with
`create-next-app`.

## Learn More

- [Next.js Documentation](https://nextjs.org/docs) - learn about features
- [Learn Next.js](https://nextjs.org/learn) - interactive tutorial
- [CLI Docs](https://nextjs.org/docs/app/api-reference/cli/create-next-app)
- [Building your app](https://nextjs.org/docs/app/building-your-application)

## Deploy

Check out [Next.js deployment docs](https://nextjs.org/docs/app/building-your-application/deploying)
for more details.
''');

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'README.md',
          relativePath: 'README.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, isEmpty);
    });

    test('does not classify a vercel.com/new boilerplate README link as a real '
        'Vercel project — a create-next-app README ships this link by default '
        'and it must not appear as an active-delete "Vercel-Projekt" entry '
        '(2026-07-20-delete-dialog-resource-over-detection)', () async {
      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString(
        'Deploy on Vercel: '
        'https://vercel.com/new?utm_medium=default-template&filter=next.js'
        '&utm_source=create-next-app&utm_campaign=create-next-app-readme',
      );

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'README.md',
          relativePath: 'README.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(
        resources.any((r) => r.type == ExternalResourceType.vercel),
        isFalse,
        reason:
            'the boilerplate vercel.com/new link must never be '
            'classified as a real, actively-deletable Vercel project',
      );
    });

    test(
      'lists a real Vercel dashboard URL alongside a boilerplate '
      'vercel.com/new link only once, correctly classified as vercel',
      () async {
        final file = File(p.join(tmp.path, 'README.md'));
        await file.writeAsString('''
Deploy on Vercel: https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme

Production: https://vercel.com/my-scope/my-project
''');

        final project = projectWithMdFiles([
          MdFileInfo(
            name: 'README.md',
            relativePath: 'README.md',
            path: file.path,
          ),
        ]);

        final resources = await detectExternalResources(project);

        final vercelResources = resources.where(
          (r) => r.type == ExternalResourceType.vercel,
        );
        expect(vercelResources, hasLength(1));
        expect(
          vercelResources.first.uri,
          equals('https://vercel.com/my-scope/my-project'),
        );
      },
    );

    test('many sub-pages of a non-resource domain do not crowd out a real '
        'resource within the 10-URL cap — the allowlist skips all of them '
        'outright, so no dedup is even needed to protect the cap', () async {
      final buffer = StringBuffer();
      for (var i = 0; i < 15; i++) {
        buffer.writeln('https://nextjs.org/docs/page-$i');
      }
      buffer.writeln('Design: https://figma.com/file/abc123');

      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString(buffer.toString());

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'README.md',
          relativePath: 'README.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, hasLength(1));
      expect(resources.first.type, ExternalResourceType.figma);
    });

    test(
      'two distinct real Vercel dashboard projects under the same '
      'vercel.com domain (e.g. prod + preview) are BOTH listed — resource '
      'domains must not be deduplicated by host, only by exact URL',
      () async {
        final file = File(p.join(tmp.path, 'README.md'));
        await file.writeAsString(
          'Prod: https://vercel.com/my-scope/my-project-prod\n'
          'Preview: https://vercel.com/my-scope/my-project-preview\n',
        );

        final project = projectWithMdFiles([
          MdFileInfo(
            name: 'README.md',
            relativePath: 'README.md',
            path: file.path,
          ),
        ]);

        final resources = await detectExternalResources(project);

        expect(resources, hasLength(2));
        expect(
          resources.every((r) => r.type == ExternalResourceType.vercel),
          isTrue,
        );
      },
    );

    test('does not classify a firebase.google.com documentation link as a '
        'Firebase project (host.contains("firebase") was too loose)', () async {
      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString(
        'See https://firebase.google.com/docs/functions for reference.',
      );

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'README.md',
          relativePath: 'README.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, isEmpty);
    });

    test('classifies a real firebaseapp.com / console.firebase.google.com '
        'project URL as ExternalResourceType.other (Firebase)', () async {
      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString(
        'Console: https://console.firebase.google.com/project/my-app/overview',
      );

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'README.md',
          relativePath: 'README.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(resources, hasLength(1));
      expect(resources.first.label, equals('Firebase-Projekt'));
    });
  });
}
