import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/features/shared/roadmap/roadmap_hero.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Future<void> pumpHero(WidgetTester tester, {String? nextMdContent}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: RoadmapHero(
            nextMdContent: nextMdContent,
            colors: AppColors.dark,
            accent: AppColors.dark.cyan,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('RoadmapHero — FR-005/FR-012', () {
    testWidgets('renders the mono eyebrow and the first content line', (
      tester,
    ) async {
      await pumpHero(
        tester,
        nextMdContent: '# Aktueller Stand\n\nWir bauen gerade M9.',
      );

      expect(find.text('NÄCHSTER SCHRITT'), findsOneWidget);
      // Heading lines (`#`) are skipped — only the first non-heading,
      // non-empty line is shown as the mockup's single-sentence summary.
      expect(find.text('Wir bauen gerade M9.'), findsOneWidget);
      expect(find.textContaining('Aktueller Stand'), findsNothing);
    });

    testWidgets('shows explicit empty state when NEXT.md content is null', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: null);

      expect(find.text('Kein nächster Schritt hinterlegt'), findsOneWidget);
    });

    testWidgets('shows explicit empty state when NEXT.md content is blank', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: '   \n  ');

      expect(find.text('Kein nächster Schritt hinterlegt'), findsOneWidget);
    });

    testWidgets(
      'shows explicit empty state when content is only headings/blank lines',
      (tester) async {
        await pumpHero(tester, nextMdContent: '# Nur eine Ueberschrift\n\n');

        expect(find.text('Kein nächster Schritt hinterlegt'), findsOneWidget);
      },
    );

    testWidgets('no crash and no raw error widget for any content', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: '# Titel\n\n- a\n- b');

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets(
      'FR-004: a long summary line renders as a single line with ellipsis '
      'overflow, never a multi-line wrap (mockup v2 .nextstep p)',
      (tester) async {
        final longLine =
            'Dieser Satz ist absichtlich sehr lang und wiederholt sich, '
            'damit er garantiert breiter als jede realistische Panel-Breite '
            'wird und den Ellipsis-Pfad statt eines Zeilenumbruchs auslöst.';

        await pumpHero(tester, nextMdContent: longLine);

        final textWidget = tester.widget<Text>(find.text(longLine));
        expect(textWidget.maxLines, 1);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      },
    );
  });
}
