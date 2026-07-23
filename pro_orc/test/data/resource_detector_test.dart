import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart'
    show deriveVercelProjectName;
import 'package:pro_orc/data/services/resource_detector.dart';
import 'package:pro_orc/data/services/vercel_detection_service.dart';

/// A [VercelDetectionService] whose `resolveTeamSlug` never shells out to
/// the real `vercel` CLI — tests must never depend on this machine's actual
/// Vercel login state or network access. `whichCommand`/`vercelCommand` are
/// pinned to `false` so [VercelDetectionService.isAvailable] (and therefore
/// [VercelDetectionService.resolveTeamSlug], which checks it first) always
/// resolves quickly to "unavailable" without spawning a real `vercel`
/// process, unless a [teamsRunner] is supplied to simulate a specific CLI
/// response.
VercelDetectionService fakeVercelDetectionService({
  VercelTeamsRunner? teamsRunner,
}) {
  return VercelDetectionService(
    whichCommand: teamsRunner != null ? 'true' : 'false',
    vercelCommand: teamsRunner != null ? 'true' : 'false',
    teamsRunner: teamsRunner ?? _unusedTeamsRunner,
  );
}

Future<ProcessResult> _unusedTeamsRunner(
  String command,
  List<String> args, {
  Duration? timeout,
}) async {
  throw StateError(
    'teamsRunner should not be invoked when the CLI is stubbed unavailable',
  );
}

/// Injects a fixed [ProcessResult] regardless of the command invoked, for
/// simulating a specific `vercel teams list --format json` response.
VercelTeamsRunner fixedTeamsRunner(ProcessResult result) {
  return (String command, List<String> args, {Duration? timeout}) async =>
      result;
}

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

    test('does not classify a vercel.com/blog marketing URL scanned from a '
        'research notes .md file as a real Vercel project — it must not '
        'appear as an active-delete "Vercel-Projekt" entry '
        '(2026-07-23-vercel-blog-url-classified-as-project-2)', () async {
      final file = File(p.join(tmp.path, 'PITFALLS.md'));
      await file.writeAsString(
        'See https://vercel.com/blog/common-mistakes-with-the-next-js-app-'
        'router-and-how-to-fix-them for details.',
      );

      final project = projectWithMdFiles([
        MdFileInfo(
          name: 'PITFALLS.md',
          relativePath: '.planning/research/PITFALLS.md',
          path: file.path,
        ),
      ]);

      final resources = await detectExternalResources(project);

      expect(
        resources.any((r) => r.type == ExternalResourceType.vercel),
        isFalse,
        reason:
            'the vercel.com/blog marketing link must never be '
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

  group('detectExternalResources — .vercel/project.json', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('resource_detector_test_');
      // Every test in this group works with orgId `team_yABWsykG53iYgFAWXpvnYn7m`
      // fixtures under different resolution outcomes — a cache hit leaking
      // from one test to the next would silently short-circuit CLI stubs.
      resetVercelTeamSlugCacheForTesting();
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    ProjectModel projectAt(Directory dir, {List<MdFileInfo>? mdFiles}) {
      return ProjectModel(
        folderId: p.basename(dir.path),
        displayName: 'Test Project',
        path: dir.path,
        projectType: ProjectType.code,
        mdFiles: mdFiles ?? const [],
      );
    }

    Future<void> writeVercelProjectJson(Directory dir, String content) async {
      final vercelDir = Directory(p.join(dir.path, '.vercel'));
      await vercelDir.create(recursive: true);
      await File(p.join(vercelDir.path, 'project.json')).writeAsString(content);
    }

    test('a project with .vercel/project.json but no md-file link is still '
        'detected as an actively-deletable Vercel resource '
        '(2026-07-21-vercel-detection-requires-md-link)', () async {
      await writeVercelProjectJson(
        tmp,
        '{"projectId":"prj_nRO4D2ZbHyO8v5XvuREdMZEOyw0P",'
        '"orgId":"team_yABWsykG53iYgFAWXpvnYn7m",'
        '"projectName":"steuerberater-scheinemann"}',
      );

      final project = projectAt(tmp);

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(),
      );

      final vercelResources = resources.where(
        (r) => r.type == ExternalResourceType.vercel,
      );
      expect(vercelResources, hasLength(1));
      expect(
        deriveVercelProjectName(vercelResources.first.uri),
        equals('steuerberater-scheinemann'),
        reason:
            'the produced resource must be actively-deletable — its uri '
            'must resolve to a real project name via '
            'deriveVercelProjectName, not stay hint-only',
      );
    });

    test('a project with .vercel/project.json AND a boilerplate '
        'vercel.com/new md-file link produces exactly one Vercel entry — '
        'from .vercel/project.json, the boilerplate link contributes nothing '
        '(2026-07-21-vercel-detection-requires-md-link)', () async {
      await writeVercelProjectJson(
        tmp,
        '{"projectId":"prj_nRO4D2ZbHyO8v5XvuREdMZEOyw0P",'
        '"orgId":"team_yABWsykG53iYgFAWXpvnYn7m",'
        '"projectName":"steuerberater-scheinemann"}',
      );

      final file = File(p.join(tmp.path, 'README.md'));
      await file.writeAsString(
        'Deploy on Vercel: '
        'https://vercel.com/new?utm_medium=default-template&filter=next.js'
        '&utm_source=create-next-app&utm_campaign=create-next-app-readme',
      );

      final project = projectAt(
        tmp,
        mdFiles: [
          MdFileInfo(
            name: 'README.md',
            relativePath: 'README.md',
            path: file.path,
          ),
        ],
      );

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(),
      );

      final vercelResources = resources.where(
        (r) => r.type == ExternalResourceType.vercel,
      );
      expect(
        vercelResources,
        hasLength(1),
        reason:
            'exactly one Vercel entry expected: from .vercel/project.json. '
            'The boilerplate md-link must not add a second entry, and '
            'must not suppress the .vercel/project.json entry either.',
      );
      expect(
        deriveVercelProjectName(vercelResources.first.uri),
        equals('steuerberater-scheinemann'),
      );
    });

    test('a project without a .vercel/ folder produces no Vercel resource from '
        'this path (existing md-scan behavior unchanged)', () async {
      final project = projectAt(tmp);

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(),
      );

      expect(
        resources.where((r) => r.type == ExternalResourceType.vercel),
        isEmpty,
      );
    });

    test('dedups (CLI-resolution success path): a real slug-form vercel.com '
        'dashboard URL in a .md file for the SAME project as '
        '.vercel/project.json produces exactly one Vercel entry — the '
        'realistic case (2026-07-23-vercel-url-uses-orgid-not-slug). '
        'Previously this test used the SAME opaque team_... id in both the '
        'synthetic and .md-file URL, which masked the real-world bug: humans '
        'write the slug form (e.g. roberts-projects-fb13711c), not the '
        'opaque id, so the two URLs are byte-different unless the opaque id '
        'is actually resolved to the slug.', () async {
      const orgId = 'team_yABWsykG53iYgFAWXpvnYn7m';
      const slug = 'roberts-projects-fb13711c';

      await writeVercelProjectJson(
        tmp,
        '{"projectId":"prj_x","orgId":"$orgId",'
        '"projectName":"my-project"}',
      );

      final file = File(p.join(tmp.path, 'STATE.md'));
      await file.writeAsString(
        'Deployed at https://vercel.com/$slug/my-project.',
      );

      final project = projectAt(
        tmp,
        mdFiles: [
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ],
      );

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(
          teamsRunner: fixedTeamsRunner(
            ProcessResult(
              0,
              0,
              '{"teams":[{"id":"$orgId","slug":"$slug"}]}',
              '',
            ),
          ),
        ),
      );

      final vercelResources = resources.where(
        (r) => r.type == ExternalResourceType.vercel,
      );
      expect(
        vercelResources,
        hasLength(1),
        reason:
            'once the opaque orgId resolves to the real slug, the '
            'synthetic URL and the human-written .md URL converge and '
            'dedup naturally via seenUris',
      );
      expect(
        vercelResources.first.uri,
        equals('https://vercel.com/$slug/my-project'),
      );
    });

    test('dedups (CLI-resolution FAILURE path): even when slug resolution '
        'fails, a slug-form .md URL for the SAME project as '
        '.vercel/project.json still produces exactly one Vercel entry — via '
        'projectName-based dedup, not URL-string equality '
        '(2026-07-23-vercel-url-uses-orgid-not-slug)', () async {
      const orgId = 'team_yABWsykG53iYgFAWXpvnYn7m';

      await writeVercelProjectJson(
        tmp,
        '{"projectId":"prj_x","orgId":"$orgId",'
        '"projectName":"my-project"}',
      );

      final file = File(p.join(tmp.path, 'STATE.md'));
      await file.writeAsString(
        'Deployed at https://vercel.com/roberts-projects-fb13711c/my-project.',
      );

      final project = projectAt(
        tmp,
        mdFiles: [
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ],
      );

      final resources = await detectExternalResources(
        project,
        // CLI unavailable — resolution fails, synthetic URL falls back to
        // the opaque orgId, which byte-differs from the .md slug URL.
        vercelDetectionService: fakeVercelDetectionService(),
      );

      final vercelResources = resources.where(
        (r) => r.type == ExternalResourceType.vercel,
      );
      expect(
        vercelResources,
        hasLength(1),
        reason:
            'projectName-based dedup must catch this even though the two '
            'URLs are byte-different (opaque orgId fallback vs. slug)',
      );
    });

    test('a corrupt/invalid .vercel/project.json is silently skipped — no '
        'crash, rest of detection still runs', () async {
      await writeVercelProjectJson(tmp, '{not valid json');

      final file = File(p.join(tmp.path, 'STATE.md'));
      await file.writeAsString(
        'Design lives at https://figma.com/file/abc123 for reference.',
      );

      final project = projectAt(
        tmp,
        mdFiles: [
          MdFileInfo(
            name: 'STATE.md',
            relativePath: 'STATE.md',
            path: file.path,
          ),
        ],
      );

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(),
      );

      expect(
        resources.where((r) => r.type == ExternalResourceType.vercel),
        isEmpty,
      );
      expect(
        resources.where((r) => r.type == ExternalResourceType.figma),
        hasLength(1),
      );
    });

    test(
      'a .vercel/project.json missing projectName is silently skipped',
      () async {
        await writeVercelProjectJson(
          tmp,
          '{"projectId":"prj_x","orgId":"team_y"}',
        );

        final project = projectAt(tmp);

        final resources = await detectExternalResources(
          project,
          vercelDetectionService: fakeVercelDetectionService(),
        );

        expect(
          resources.where((r) => r.type == ExternalResourceType.vercel),
          isEmpty,
        );
      },
    );

    test('slug resolution failure never crashes/hangs detection — a project '
        'with a valid orgId still yields a resource (fallback URL) even when '
        'the CLI is unavailable', () async {
      await writeVercelProjectJson(
        tmp,
        '{"projectId":"prj_x","orgId":"team_yABWsykG53iYgFAWXpvnYn7m",'
        '"projectName":"my-project"}',
      );

      final project = projectAt(tmp);

      final resources = await detectExternalResources(
        project,
        vercelDetectionService: fakeVercelDetectionService(),
      );

      final vercelResources = resources.where(
        (r) => r.type == ExternalResourceType.vercel,
      );
      expect(vercelResources, hasLength(1));
      expect(
        vercelResources.first.uri,
        equals('https://vercel.com/team_yABWsykG53iYgFAWXpvnYn7m/my-project'),
        reason:
            'fallback to the opaque orgId (pre-fix behavior) — still '
            'listed and attributable, just non-routable, when CLI '
            'resolution fails',
      );
    });

    test(
      'in-memory team-slug cache: two projects under the same orgId only '
      'invoke the teams-list CLI call once — not once per project '
      '(2026-07-23-vercel-url-uses-orgid-not-slug caching requirement)',
      () async {
        const orgId = 'team_yABWsykG53iYgFAWXpvnYn7m';
        const slug = 'roberts-projects-fb13711c';
        var callCount = 0;

        VercelDetectionService serviceForCall() => fakeVercelDetectionService(
          teamsRunner: (command, args, {timeout}) async {
            callCount++;
            return ProcessResult(
              0,
              0,
              '{"teams":[{"id":"$orgId","slug":"$slug"}]}',
              '',
            );
          },
        );

        final tmp2 = await Directory.systemTemp.createTemp(
          'resource_detector_test_',
        );
        addTearDown(() async {
          if (await tmp2.exists()) await tmp2.delete(recursive: true);
        });

        await writeVercelProjectJson(
          tmp,
          '{"projectId":"prj_a","orgId":"$orgId","projectName":"project-a"}',
        );
        await writeVercelProjectJson(
          tmp2,
          '{"projectId":"prj_b","orgId":"$orgId","projectName":"project-b"}',
        );

        final resourcesA = await detectExternalResources(
          projectAt(tmp),
          vercelDetectionService: serviceForCall(),
        );
        final resourcesB = await detectExternalResources(
          projectAt(tmp2),
          vercelDetectionService: serviceForCall(),
        );

        expect(
          resourcesA
              .firstWhere((r) => r.type == ExternalResourceType.vercel)
              .uri,
          equals('https://vercel.com/$slug/project-a'),
        );
        expect(
          resourcesB
              .firstWhere((r) => r.type == ExternalResourceType.vercel)
              .uri,
          equals('https://vercel.com/$slug/project-b'),
        );
        expect(
          callCount,
          equals(1),
          reason:
              'the second project shares the same orgId, so its slug '
              'must come from the in-memory cache, not a second CLI call',
        );
      },
    );
  });
}
