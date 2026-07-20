import 'dart:io';

import 'package:test/test.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/services/deletion_service.dart';
import 'package:pro_orc/data/services/external_deletion_service.dart';

/// A [ProcessRunner] that returns a fixed, injected result for every call —
/// used to simulate `gh` outcomes without spawning real processes.
ProcessRunner fixedRunner({required int exitCode, String stderr = ''}) {
  return (
    String executable,
    List<String> arguments, {
    bool runInShell = true,
  }) async {
    return ProcessResult(0, exitCode, '', stderr);
  };
}

void main() {
  group('buildFinderDeleteScript', () {
    test('generates AppleScript for a plain path', () {
      final script = buildFinderDeleteScript('/Users/rob/code/my-project');

      expect(
        script,
        'tell application "Finder" to delete POSIX file '
        '"/Users/rob/code/my-project"',
      );
    });

    test('escapes double quotes in the path so it cannot break out', () {
      final script = buildFinderDeleteScript('/tmp/a"b');

      expect(
        script,
        r'tell application "Finder" to delete POSIX file "/tmp/a\"b"',
      );
    });

    test('a path containing AppleScript-breaking metacharacters cannot '
        'inject an additional Finder command', () {
      final malicious = '/tmp/x" & (do shell script "rm -rf ~") & "';
      final script = buildFinderDeleteScript(malicious);

      // The raw unescaped payload must never appear verbatim — the
      // quotes inside it are escaped so it stays inert data.
      expect(script, isNot(contains(malicious)));
      expect(
        script,
        r'tell application "Finder" to delete POSIX file '
        r'"/tmp/x\" & (do shell script \"rm -rf ~\") & \""',
      );
    });

    test('escapes backslashes before quotes', () {
      final script = buildFinderDeleteScript(r'/tmp/a\b"c');

      expect(
        script,
        r'tell application "Finder" to delete POSIX file "/tmp/a\\b\"c"',
      );
    });
  });

  group('deleteProject', () {
    test('returns false when directory does not exist', () async {
      final result = await deleteProject('/tmp/nonexistent_project_xyz_999');
      expect(result, isFalse);
    });

    test(
      'moves an existing directory to the Trash and removes it from its original location',
      () async {
        final tmp = await Directory.systemTemp.createTemp(
          'deletion_service_test_',
        );
        final projectDir = Directory('${tmp.path}/my-project');
        await projectDir.create();
        await File('${projectDir.path}/README.md').writeAsString('# Test');

        final result = await deleteProject(projectDir.path);

        expect(result, isTrue);
        expect(await projectDir.exists(), isFalse);

        // Clean up: find the moved item in ~/.Trash and remove it so repeated
        // test runs don't accumulate junk. Best-effort — do not fail the test
        // if this cleanup step itself fails.
        try {
          final home = Platform.environment['HOME'];
          if (home != null) {
            final trashed = Directory('$home/.Trash/my-project');
            if (await trashed.exists()) {
              await trashed.delete(recursive: true);
            }
          }
        } catch (_) {}

        await tmp.delete(recursive: true).catchError((_) => tmp);
      },
    );
  });

  group('deleteSelectedExternalResources', () {
    test('one failing resource does not prevent the others from completing '
        'in the same run (FR-008 — independence)', () async {
      // Two GitHub resources sharing one runner that fails for the
      // first repo and succeeds for the second — proves failures don't
      // abort the batch.
      var callCount = 0;
      Future<ProcessResult> perCallRunner(
        String executable,
        List<String> arguments, {
        bool runInShell = true,
      }) async {
        callCount++;
        final args = arguments;
        if (args.contains('owner/fails')) {
          return ProcessResult(0, 1, '', 'some unexpected server error');
        }
        return ProcessResult(0, 0, '', '');
      }

      final resources = [
        const ExternalResource(
          type: ExternalResourceType.github,
          label: 'GitHub-Repository',
          uri: 'https://github.com/owner/fails',
          hint: 'x',
        ),
        const ExternalResource(
          type: ExternalResourceType.github,
          label: 'GitHub-Repository',
          uri: 'https://github.com/owner/succeeds',
          hint: 'x',
        ),
      ];

      final results = await deleteSelectedExternalResources(
        resources,
        ghRunner: perCallRunner,
      );

      expect(callCount, 2);
      expect(results, hasLength(2));
      final failing = results.firstWhere(
        (r) => r.uri == 'https://github.com/owner/fails',
      );
      final succeeding = results.firstWhere(
        (r) => r.uri == 'https://github.com/owner/succeeds',
      );
      expect(failing.succeeded, isFalse);
      expect(succeeding.succeeded, isTrue);
    });

    test('a Figma resource is NEVER dispatched to a runner (FR-010) — the '
        'injected runner is not invoked for it and it is absent from the '
        'result list entirely', () async {
      var runnerInvoked = false;
      Future<ProcessResult> trackingRunner(
        String executable,
        List<String> arguments, {
        bool runInShell = true,
      }) async {
        runnerInvoked = true;
        return ProcessResult(0, 0, '', '');
      }

      final resources = [
        const ExternalResource(
          type: ExternalResourceType.figma,
          label: 'Figma-Design',
          uri: 'https://figma.com/file/abc123',
          hint: 'Manuell im Browser oeffnen und ggf. loeschen',
        ),
      ];

      final results = await deleteSelectedExternalResources(
        resources,
        ghRunner: trackingRunner,
      );

      expect(runnerInvoked, isFalse);
      expect(results, isEmpty);
    });

    test('onResult fires once per attempted (non-Figma) resource as its '
        'DeletionResult becomes available', () async {
      final delivered = <String>[];

      final resources = [
        const ExternalResource(
          type: ExternalResourceType.github,
          label: 'GitHub-Repository',
          uri: 'https://github.com/owner/repo',
          hint: 'x',
        ),
        const ExternalResource(
          type: ExternalResourceType.figma,
          label: 'Figma-Design',
          uri: 'https://figma.com/file/abc123',
          hint: 'x',
        ),
      ];

      await deleteSelectedExternalResources(
        resources,
        ghRunner: fixedRunner(exitCode: 0),
        onResult: (result) => delivered.add(result.uri),
      );

      // Only the GitHub resource is dispatched/reported — Figma never
      // triggers onResult (FR-010).
      expect(delivered, ['https://github.com/owner/repo']);
    });

    test('a Claude memory resource is deleted from disk independently of '
        'other resources in the same run', () async {
      final tmp = await Directory.systemTemp.createTemp(
        'delete_selected_ext_test_',
      );
      final memDir = Directory('${tmp.path}/claude_project');
      await memDir.create();

      final resources = [
        ExternalResource(
          type: ExternalResourceType.claudeMemory,
          label: 'Claude Memory',
          uri: memDir.path,
          hint: 'x',
        ),
      ];

      final results = await deleteSelectedExternalResources(resources);

      expect(results, hasLength(1));
      expect(results.first.succeeded, isTrue);
      expect(await memDir.exists(), isFalse);

      await tmp.delete(recursive: true).catchError((_) => tmp);
    });
  });
}
