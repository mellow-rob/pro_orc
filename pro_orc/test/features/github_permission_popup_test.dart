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
}
