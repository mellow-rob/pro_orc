import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/features/shared/roadmap/structured_spec_renderer.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Real temp-file fixtures, per project convention (no mocked file I/O).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('structured_spec_renderer_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String writeSpec(String content, {String name = 'spec.md'}) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsStringSync(content);
    return file.path;
  }

  Future<void> pumpRenderer(
    WidgetTester tester, {
    String? specPath,
    String? planPath,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: StructuredSpecRenderer(
            specPath: specPath,
            planPath: planPath,
            colors: AppColors.dark,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('StructuredSpecRenderer — recognized sections (FR-017)', () {
    testWidgets('renders Acceptance Criteria as a checklist', (tester) async {
      final path = writeSpec('''
## Discovery — Problem

Users cannot see the spec content in a readable way.

## Discovery — Acceptance Criteria

- Given a feature card, when tapped, then the spec opens
- Given a missing file, when opened, then a fallback is shown
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
      expect(find.textContaining('Given a feature card'), findsOneWidget);
    });

    testWidgets('renders Out of Scope as an info box', (tester) async {
      final path = writeSpec('''
## Discovery — Out of Scope

- Editing specs is not supported
- Multi-language specs are not supported
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.byKey(const Key('out_of_scope_box')), findsOneWidget);
      expect(find.textContaining('Editing specs'), findsOneWidget);
    });

    testWidgets('renders Edge Cases as warning cards', (tester) async {
      final path = writeSpec('''
## Discovery — Edge Cases

- What happens when the file is empty?
- What happens when frontmatter is malformed?
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
      expect(find.textContaining('empty'), findsOneWidget);
    });

    testWidgets('renders Success Metrics as tiles', (tester) async {
      final path = writeSpec('''
## Discovery — Success Metrics

- 100% of specs render without raw Markdown
- 0 crashes on missing files
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.byKey(const Key('success_metrics_grid')), findsOneWidget);
      expect(find.textContaining('100%'), findsOneWidget);
    });

    testWidgets('tolerates German section variant "Erfolgsmetriken"', (
      tester,
    ) async {
      final path = writeSpec('''
## Erfolgsmetriken

- 100% Abdeckung
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.byKey(const Key('success_metrics_grid')), findsOneWidget);
    });

    testWidgets('tolerates plain "Problem" heading without "Discovery —"', (
      tester,
    ) async {
      final path = writeSpec('''
## Problem

Some prose describing the problem.
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.textContaining('Some prose describing'), findsOneWidget);
    });

    testWidgets('renders User Journey as prose block', (tester) async {
      final path = writeSpec('''
## User Journey

The user opens the roadmap, taps a milestone, then a feature.
''');

      await pumpRenderer(tester, specPath: path);

      expect(find.textContaining('The user opens the roadmap'), findsOneWidget);
    });
  });

  group('StructuredSpecRenderer — freeform fallback (FR-018)', () {
    testWidgets('renders unrecognized sections as formatted Markdown, '
        'never as raw monospace text', (tester) async {
      final path = writeSpec('''
## Some Unknown Section

This has **bold** and *italic* text plus a list:

- item one
- item two
''');

      await pumpRenderer(tester, specPath: path);

      // No monospace SelectableText anywhere — that was the old
      // SpecViewer behavior this wave replaces.
      final selectableTextFinder = find.byWidgetPredicate((widget) {
        if (widget is! SelectableText) return false;
        final style = widget.style;
        return style?.fontFamily == 'monospace';
      });
      expect(selectableTextFinder, findsNothing);
    });
  });

  group('StructuredSpecRenderer — missing file fallback (FR-019)', () {
    testWidgets('shows "Spec nicht verfügbar" when specPath file is missing', (
      tester,
    ) async {
      await pumpRenderer(
        tester,
        specPath: p.join(tempDir.path, 'does_not_exist.md'),
      );

      expect(find.textContaining('Spec nicht verfügbar'), findsOneWidget);
    });

    testWidgets('shows "Plan nicht verfügbar" when the Plan tab is active '
        'and planPath file is missing', (tester) async {
      final specPathFile = writeSpec('## Problem\n\nSome text.');

      await pumpRenderer(
        tester,
        specPath: specPathFile,
        planPath: p.join(tempDir.path, 'missing_plan.md'),
      );

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Plan nicht verfügbar'), findsOneWidget);
    });

    testWidgets('shows "Spec nicht verfügbar" when specPath is null', (
      tester,
    ) async {
      await pumpRenderer(tester, specPath: null);

      expect(find.textContaining('Spec nicht verfügbar'), findsOneWidget);
    });

    testWidgets('shows German empty state when file exists but is blank', (
      tester,
    ) async {
      final path = writeSpec('   \n  ');

      await pumpRenderer(tester, specPath: path);

      expect(find.textContaining('Spec nicht verfügbar'), findsOneWidget);
    });
  });

  group('StructuredSpecRenderer — Spec/Plan toggle', () {
    testWidgets('shows Spec content by default and switches to Plan on tap', (
      tester,
    ) async {
      final specPathFile = writeSpec('## Problem\n\nSpec-Inhalt hier.');
      final planPathFile = writeSpec(
        '## Problem\n\nPlan-Inhalt hier.',
        name: 'plan.md',
      );

      await pumpRenderer(
        tester,
        specPath: specPathFile,
        planPath: planPathFile,
      );

      expect(find.textContaining('Spec-Inhalt hier'), findsOneWidget);
      expect(find.textContaining('Plan-Inhalt hier'), findsNothing);

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Plan-Inhalt hier'), findsOneWidget);
      expect(find.textContaining('Spec-Inhalt hier'), findsNothing);

      await tester.tap(find.text('Spec'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Spec-Inhalt hier'), findsOneWidget);
    });

    testWidgets('toggle is present even when planPath is null', (tester) async {
      final specPathFile = writeSpec('## Problem\n\nNur Spec vorhanden.');

      await pumpRenderer(tester, specPath: specPathFile, planPath: null);

      expect(find.text('Spec'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);

      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Plan nicht verfügbar'), findsOneWidget);
    });
  });
}
