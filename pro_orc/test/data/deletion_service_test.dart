import 'dart:io';

import 'package:test/test.dart';

import 'package:pro_orc/data/services/deletion_service.dart';

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

    test(
      'a path containing AppleScript-breaking metacharacters cannot '
      'inject an additional Finder command',
      () {
        final malicious =
            '/tmp/x" & (do shell script "rm -rf ~") & "';
        final script = buildFinderDeleteScript(malicious);

        // The raw unescaped payload must never appear verbatim — the
        // quotes inside it are escaped so it stays inert data.
        expect(script, isNot(contains(malicious)));
        expect(
          script,
          r'tell application "Finder" to delete POSIX file '
          r'"/tmp/x\" & (do shell script \"rm -rf ~\") & \""',
        );
      },
    );

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
}
