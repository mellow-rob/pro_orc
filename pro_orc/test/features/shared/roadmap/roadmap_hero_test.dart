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
  });
}
