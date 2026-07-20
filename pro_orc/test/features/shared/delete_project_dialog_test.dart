import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/data/services/memory_reader.dart'
    show encodeProjectPath;
import 'package:pro_orc/data/services/vercel_detection_service.dart';
import 'package:pro_orc/features/shared/delete_project_dialog.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// [ExternalResource]-producing fixtures reuse the real
/// `detectExternalResources` path — real project directories with a github
/// URL in [ProjectModel.git], vercel.com dashboard URLs in real .md files,
/// and (for Claude memory) a real directory under the actual
/// `~/.claude/projects/<encoded>` path, exactly like
/// `resource_detector_test.dart` and the project's "real temp dirs, no
/// mocks" convention.
///
/// All filesystem setup happens in [setUpAll]/[tearDownAll] rather than per
/// test or inside a `testWidgets` body — `Directory.systemTemp.createTemp()`
/// (and other async dart:io calls) executed while the `flutter_tester`
/// widget-test binding is active can stall indefinitely in this
/// environment; running it once, before any `testWidgets` pump activates
/// that binding, avoids the stall entirely.
void main() {
  group('DeleteProjectDialog — Wave 2 resource rendering', () {
    late Directory root;
    late ProjectModel vercelTwoProject;
    late ProjectModel githubProject;
    late ProjectModel claudeMemoryProject;
    late ProjectModel vercelOneProject;
    late ProjectModel githubAndVercelProject;
    late Directory claudeMemoryDir;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('delete_dialog_test_');

      Future<ProjectModel> makeProject(
        String name, {
        bool withGithub = false,
        String? mdContent,
      }) async {
        final dir = Directory(p.join(root.path, name));
        await dir.create(recursive: true);
        final mdFiles = <MdFileInfo>[];
        if (mdContent != null) {
          final file = File(p.join(dir.path, 'STATE.md'));
          await file.writeAsString(mdContent);
          mdFiles.add(
            MdFileInfo(
              name: 'STATE.md',
              relativePath: 'STATE.md',
              path: file.path,
            ),
          );
        }
        return ProjectModel(
          folderId: name,
          displayName: 'Test Project',
          path: dir.path,
          projectType: ProjectType.code,
          git: withGithub
              ? const GitData(
                  githubUrl: 'https://github.com/n3urala1-rob/a1-pro-orc',
                )
              : null,
          mdFiles: mdFiles,
        );
      }

      vercelTwoProject = await makeProject(
        'vercel_two',
        mdContent:
            'Prod: https://vercel.com/my-scope/my-project-prod\n'
            'Preview: https://vercel.com/my-scope/my-project-preview\n',
      );
      githubProject = await makeProject('github_only', withGithub: true);
      vercelOneProject = await makeProject(
        'vercel_one',
        mdContent:
            'Deployed at https://vercel.com/my-scope/my-project for prod.',
      );
      githubAndVercelProject = await makeProject(
        'github_and_vercel',
        withGithub: true,
        mdContent:
            'Deployed at https://vercel.com/my-scope/my-project for prod.',
      );

      // Claude memory: a real directory under the actual
      // ~/.claude/projects/<encoded-path> path, matching how
      // resource_detector.dart discovers it.
      final claudeMemorySourceProject = await makeProject('claude_memory');
      final home = Platform.environment['HOME']!;
      final encoded = encodeProjectPath(claudeMemorySourceProject.path);
      claudeMemoryDir = Directory(p.join(home, '.claude', 'projects', encoded));
      await claudeMemoryDir.create(recursive: true);
      claudeMemoryProject = claudeMemorySourceProject;
    });

    tearDownAll(() async {
      if (await root.exists()) await root.delete(recursive: true);
      if (await claudeMemoryDir.exists()) {
        await claudeMemoryDir.delete(recursive: true);
      }
    });

    Future<void> pumpDialog(
      WidgetTester tester,
      ProjectModel project, {
      required bool vercelAvailable,
      required bool ghAvailable,
    }) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // _loadResources() and _resolveAvailability() (started from
      // initState) spawn real processes (Process.run) and do real file
      // I/O. If pumpWidget itself is called outside tester.runAsync(),
      // those real async operations start in the fake-async test zone and
      // their completion callbacks never fire — the test hangs forever,
      // not just fails. Wrapping pumpWidget in runAsync, then awaiting
      // the dialog's exposed initialLoad future in a second runAsync,
      // lets both operations actually run against the real event loop.
      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ProviderContainer(),
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: const [AppColors.dark],
              ),
              home: Scaffold(
                body: DeleteProjectDialog(
                  project: project,
                  vercelDetectionService: VercelDetectionService(
                    whichCommand: vercelAvailable ? 'true' : 'false',
                    vercelCommand: 'true',
                  ),
                  ghDetectionService: GhDetectionService(
                    whichCommand: ghAvailable ? 'true' : 'false',
                    ghCommand: 'true',
                  ),
                ),
              ),
            ),
          ),
        );
      });

      final state = tester.state<State<DeleteProjectDialog>>(
        find.byType(DeleteProjectDialog),
      );
      await tester.runAsync(
        () => (state as dynamic).initialLoad as Future<void>,
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'two linked Vercel projects render two independent enabled checkboxes '
      'when VercelDetectionService is available (FR-003)',
      (tester) async {
        await pumpDialog(
          tester,
          vercelTwoProject,
          vercelAvailable: true,
          ghAvailable: true,
        );

        expect(find.byType(Checkbox), findsNWidgets(2));

        // Both are independently toggleable.
        await tester.tap(find.byType(Checkbox).first);
        await tester.pump();
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isTrue,
        );
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).last).value,
          isFalse,
        );
      },
    );

    testWidgets(
      'a detected GitHub repo renders an enabled active-delete checkbox '
      'when GhDetectionService is available (FR-004)',
      (tester) async {
        await pumpDialog(
          tester,
          githubProject,
          vercelAvailable: false,
          ghAvailable: true,
        );

        expect(find.byType(Checkbox), findsOneWidget);
        expect(find.text('nur Hinweis'), findsOneWidget);
      },
    );

    testWidgets('a detected Claude memory directory always renders an enabled '
        'checkbox regardless of CLI availability (FR-005)', (tester) async {
      await pumpDialog(
        tester,
        claudeMemoryProject,
        vercelAvailable: false,
        ghAvailable: false,
      );

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
        isNotNull,
      );
    });

    testWidgets(
      'when gh is NOT installed/authenticated, the GitHub resource shows '
      'NO active-delete checkbox and the hint-only status text (FR-006)',
      (tester) async {
        await pumpDialog(
          tester,
          githubProject,
          vercelAvailable: true,
          ghAvailable: false,
        );

        expect(find.byType(Checkbox), findsNothing);
        expect(find.textContaining('Token fehlt'), findsOneWidget);
      },
    );

    testWidgets(
      'when vercel is NOT installed/authenticated, the Vercel resource '
      'shows NO active-delete checkbox and the hint-only status text '
      '(FR-006)',
      (tester) async {
        await pumpDialog(
          tester,
          vercelOneProject,
          vercelAvailable: false,
          ghAvailable: true,
        );

        expect(find.byType(Checkbox), findsNothing);
        expect(find.textContaining('Token fehlt'), findsOneWidget);
      },
    );

    testWidgets(
      'checking an available Vercel resource flips its status text to '
      '"wird aktiv geloescht" (Variant A per-row status)',
      (tester) async {
        await pumpDialog(
          tester,
          vercelOneProject,
          vercelAvailable: true,
          ghAvailable: true,
        );

        expect(find.text('nur Hinweis'), findsOneWidget);

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(find.text('wird aktiv geloescht'), findsOneWidget);
        expect(find.text('nur Hinweis'), findsNothing);
      },
    );

    testWidgets(
      'the dialog contains no token/credential input field and stores no '
      'secret — gating is solely CLI-availability driven (FR-013)',
      (tester) async {
        await pumpDialog(
          tester,
          githubAndVercelProject,
          vercelAvailable: true,
          ghAvailable: true,
        );

        // The only TextField in the dialog is the project-name confirmation
        // field (existing convention) — no token/API-key input exists.
        final textFields = find.byType(TextField);
        expect(textFields, findsOneWidget);
        final textField = tester.widget<TextField>(textFields);
        expect(
          textField.decoration?.hintText,
          'Projektname zur Bestaetigung eingeben',
        );

        // No password-obscured field either (a token field would typically
        // be obscured).
        expect(textField.obscureText, isFalse);
      },
    );
  });
}
