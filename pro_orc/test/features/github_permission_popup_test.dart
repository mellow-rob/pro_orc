import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/services/gh_detection_service.dart';
import 'package:pro_orc/features/shared/github_permission_popup.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Widget wrapInMaterial(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
      home: Scaffold(body: child),
    );
  }

  /// Pumps a Scaffold with a button that opens [GithubPermissionPopup] via
  /// [showDialog] for [status], recording every call to [onOpenTerminal].
  /// Returns the count of calls so tests can assert exactly how many times
  /// (0 or 1) the runner fired.
  Future<void> pumpAndOpenPopup(
    WidgetTester tester, {
    required GhScopeStatus status,
    required void Function() onOpenTerminal,
    String? repoOwner,
  }) async {
    await tester.pumpWidget(
      wrapInMaterial(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => GithubPermissionPopup(
                status: status,
                onOpenTerminal: onOpenTerminal,
                repoOwner: repoOwner,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Walks the `Text.rich` body's `TextSpan` tree (depth-first) and
  /// returns the first span whose plain text exactly matches [text], or
  /// null. Checks [root] itself first, then descends into its children.
  TextSpan? findSpanWithText(InlineSpan root, String text) {
    if (root is TextSpan && root.text == text) return root;
    TextSpan? result;
    final children = root is TextSpan ? root.children : null;
    if (children != null) {
      for (final child in children) {
        result = findSpanWithText(child, text);
        if (result != null) break;
      }
    }
    return result;
  }

  group('GithubPermissionPopup — scope missing', () {
    testWidgets('shows title, body, action button, and Abbrechen button', (
      tester,
    ) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () {},
      );

      expect(find.text('Berechtigung fehlt'), findsOneWidget);
      expect(
        find.textContaining('delete_repo'),
        findsWidgets,
        reason: 'body text must reference the missing delete_repo scope',
      );
      expect(
        find.text('Terminal oeffnen & Berechtigung nachfordern'),
        findsOneWidget,
      );
      expect(find.text('Abbrechen'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('tapping the action button invokes onOpenTerminal exactly '
        'once and closes the popup', (tester) async {
      var callCount = 0;

      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () => callCount++,
      );

      expect(find.text('Berechtigung fehlt'), findsOneWidget);

      await tester.tap(
        find.text('Terminal oeffnen & Berechtigung nachfordern'),
      );
      await tester.pumpAndSettle();

      expect(callCount, 1);
      expect(find.text('Berechtigung fehlt'), findsNothing);
    });

    testWidgets('tapping the close (X) icon dismisses without invoking the '
        'runner', (tester) async {
      var callCount = 0;

      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () => callCount++,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('Berechtigung fehlt'), findsNothing);
    });

    testWidgets('tapping Abbrechen dismisses without invoking the runner', (
      tester,
    ) async {
      var callCount = 0;

      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () => callCount++,
      );

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('Berechtigung fehlt'), findsNothing);
    });

    testWidgets('tapping outside the dialog dismisses without invoking the '
        'runner', (tester) async {
      var callCount = 0;

      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () => callCount++,
      );

      // Tap the barrier — top-left corner of the screen, well outside the
      // centered dialog content.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(callCount, 0);
      expect(find.text('Berechtigung fehlt'), findsNothing);
    });
  });

  group('GithubPermissionPopup — checkFailed (treated like missing)', () {
    testWidgets('renders the same missing-scope body and action button', (
      tester,
    ) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.checkFailed,
        onOpenTerminal: () {},
      );

      expect(find.text('Berechtigung fehlt'), findsOneWidget);
      expect(
        find.text('Terminal oeffnen & Berechtigung nachfordern'),
        findsOneWidget,
      );
    });
  });

  group('GithubPermissionPopup — cliUnavailable', () {
    testWidgets('shows the distinct cli-unavailable body text and hides the '
        'refresh action button', (tester) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.cliUnavailable,
        onOpenTerminal: () {},
      );

      expect(
        find.text(
          'GitHub CLI (gh) ist nicht installiert oder nicht angemeldet',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Terminal oeffnen & Berechtigung nachfordern'),
        findsNothing,
        reason:
            'the delete_repo refresh action is misleading when gh itself '
            'is unavailable — it must not be offered',
      );
      // Close/Abbrechen must still be present so the popup remains
      // dismissible even without an action button.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Abbrechen'), findsOneWidget);
    });

    testWidgets('closing via Abbrechen does not invoke onOpenTerminal', (
      tester,
    ) async {
      var callCount = 0;

      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.cliUnavailable,
        onOpenTerminal: () => callCount++,
      );

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });
  });

  group('GithubPermissionPopup — repo owner (Spec 009, FR-001)', () {
    testWidgets('missing: owner substring is present in the rendered body', (
      tester,
    ) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () {},
        repoOwner: 'acme-corp',
      );

      expect(find.textContaining('acme-corp'), findsWidgets);
    });

    testWidgets(
      'checkFailed: owner substring is present in the rendered body',
      (tester) async {
        await pumpAndOpenPopup(
          tester,
          status: GhScopeStatus.checkFailed,
          onOpenTerminal: () {},
          repoOwner: 'acme-corp',
        );

        expect(find.textContaining('acme-corp'), findsWidgets);
      },
    );

    testWidgets(
      'cliUnavailable: owner substring is present in the rendered body',
      (tester) async {
        await pumpAndOpenPopup(
          tester,
          status: GhScopeStatus.cliUnavailable,
          onOpenTerminal: () {},
          repoOwner: 'acme-corp',
        );

        expect(find.textContaining('acme-corp'), findsWidgets);
      },
    );

    testWidgets('cliUnavailable: owner sentence stays neutral (no "melde dich" '
        'call-to-action) since gh is not even running yet (review fix)', (
      tester,
    ) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.cliUnavailable,
        onOpenTerminal: () {},
        repoOwner: 'acme-corp',
      );

      expect(find.textContaining('gehoert zu'), findsWidgets);
      expect(
        find.textContaining('melde dich im Terminal mit einem Account'),
        findsNothing,
        reason:
            'gh is not installed/logged in yet in this state — asking '
            'the user to sign in with a SPECIFIC account is premature '
            'and contradicts the cli-unavailable body text that follows',
      );
    });

    testWidgets('missing: owner sentence keeps the "melde dich" call-to-action '
        '(unchanged — gh is already running here, only the scope is '
        'missing)', (tester) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.missing,
        onOpenTerminal: () {},
        repoOwner: 'acme-corp',
      );

      expect(
        find.textContaining('melde dich im Terminal mit einem Account'),
        findsWidgets,
      );
    });

    testWidgets(
      'the owner span is bold while the surrounding prose is NOT bold '
      '(discriminating — proves emphasis is scoped to the owner only)',
      (tester) async {
        await pumpAndOpenPopup(
          tester,
          status: GhScopeStatus.missing,
          onOpenTerminal: () {},
          repoOwner: 'acme-corp',
        );

        final richTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('acme-corp'),
        );
        expect(richTextFinder, findsOneWidget);

        final richText = tester.widget<RichText>(richTextFinder);
        final ownerSpan = findSpanWithText(richText.text, 'acme-corp');
        expect(
          ownerSpan,
          isNotNull,
          reason: 'expected a dedicated TextSpan for the owner substring',
        );
        expect(ownerSpan!.style?.fontWeight, FontWeight.bold);

        // Negative control: the surrounding prose must NOT be bold — proves
        // a test asserting "some span somewhere is bold" would be
        // insufficient; the emphasis must be scoped to the owner only.
        var foundNonBoldProse = false;
        void visit(InlineSpan span) {
          if (span is TextSpan &&
              span.text != null &&
              span.text!.trim().isNotEmpty &&
              span.text != 'acme-corp') {
            if (span.style?.fontWeight != FontWeight.bold) {
              foundNonBoldProse = true;
            }
          }
          if (span is TextSpan) {
            for (final child in span.children ?? const <InlineSpan>[]) {
              visit(child);
            }
          }
        }

        visit(richText.text);
        expect(
          foundNonBoldProse,
          isTrue,
          reason: 'surrounding prose must remain non-bold',
        );
      },
    );
  });

  group('GithubPermissionPopup — owner fallback (Spec 009, FR-002)', () {
    testWidgets(
      'repoOwner == null falls back to the previous owner-less missing-scope '
      'text with no crash and no empty/placeholder token',
      (tester) async {
        await pumpAndOpenPopup(
          tester,
          status: GhScopeStatus.missing,
          onOpenTerminal: () {},
          repoOwner: null,
        );

        expect(
          find.text(
            'Die aktuelle GitHub-CLI-Session hat nicht den '
            "'delete_repo'-Scope. Dieser Scope muss gewaehrt werden, bevor "
            'das Repository geloescht werden kann.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('gehoert zu'), findsNothing);
      },
    );

    testWidgets('repoOwner == null falls back to the previous owner-less '
        'cliUnavailable text with no crash and no empty/placeholder token', (
      tester,
    ) async {
      await pumpAndOpenPopup(
        tester,
        status: GhScopeStatus.cliUnavailable,
        onOpenTerminal: () {},
        repoOwner: null,
      );

      expect(
        find.text(
          'GitHub CLI (gh) ist nicht installiert oder nicht angemeldet',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('gehoert zu'), findsNothing);
    });
  });

  group('extractGithubOwner (Spec 009, FR-001/FR-002)', () {
    test('well-formed githubUrl returns the owner path segment', () {
      expect(
        extractGithubOwner('https://github.com/acme-corp/some-repo'),
        'acme-corp',
      );
    });

    test('ownerless githubUrl (empty path) returns null, not empty string', () {
      expect(extractGithubOwner('https://github.com/'), isNull);
    });

    test('non-URL input returns null', () {
      expect(extractGithubOwner('not a url'), isNull);
    });
  });
}
