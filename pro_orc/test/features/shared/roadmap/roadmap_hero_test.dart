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

  group('RoadmapHero — FR-012', () {
    testWidgets('renders NEXT.md content when present', (tester) async {
      await pumpHero(
        tester,
        nextMdContent: '# Aktueller Stand\n\nWir bauen gerade M9.',
      );

      expect(find.textContaining('Aktueller Stand'), findsOneWidget);
      expect(find.textContaining('Wir bauen gerade M9.'), findsOneWidget);
    });

    testWidgets('shows explicit empty state when NEXT.md content is null', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: null);

      expect(find.text('Kein naechster Schritt hinterlegt'), findsOneWidget);
    });

    testWidgets('shows explicit empty state when NEXT.md content is blank', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: '   \n  ');

      expect(find.text('Kein naechster Schritt hinterlegt'), findsOneWidget);
    });

    testWidgets('no crash and no raw error widget for any content', (
      tester,
    ) async {
      await pumpHero(tester, nextMdContent: '# Titel\n\n- a\n- b');

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}
