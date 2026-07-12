import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/features/onboarding/steps/claude_check_step.dart';
import 'package:pro_orc/features/onboarding/steps/project_preview_step.dart';
import 'package:pro_orc/features/onboarding/steps/scan_dirs_step.dart';
import 'package:pro_orc/theme/n3_colors.dart';

void main() {
  Widget wrapInMaterial(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
      home: Scaffold(body: child),
    );
  }

  group('ClaudeCheckStep', () {
    testWidgets('shows install help when not installed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInMaterial(
          ClaudeCheckStep(
            isInstalled: false,
            version: null,
            onRecheck: () {},
            autostart: false,
            onAutostartChanged: (_) {},
          ),
        ),
      );

      expect(
        find.text('npm install -g @anthropic-ai/claude-code'),
        findsOneWidget,
      );
      expect(find.text('Erneut pruefen'), findsOneWidget);
      expect(
        find.text('Claude Code ist ein KI-Assistent fuer die Kommandozeile.'),
        findsOneWidget,
      );
    });

    testWidgets('shows success state when installed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInMaterial(
          ClaudeCheckStep(
            isInstalled: true,
            version: '1.0.42',
            onRecheck: () {},
            autostart: false,
            onAutostartChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Claude Code ist installiert'), findsOneWidget);
      expect(find.text('Version: 1.0.42'), findsOneWidget);
      expect(
        find.text('npm install -g @anthropic-ai/claude-code'),
        findsNothing,
      );
    });

    testWidgets('autostart toggle is visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInMaterial(
          ClaudeCheckStep(
            isInstalled: true,
            version: null,
            onRecheck: () {},
            autostart: false,
            onAutostartChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Beim Login starten'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });
  });

  group('ScanDirsStep', () {
    testWidgets('renders added directories with remove buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInMaterial(
          ScanDirsStep(
            scanDirs: const ['/Users/test/projects', '/Users/test/code'],
            onAddDir: () {},
            onRemoveDir: (_) {},
          ),
        ),
      );

      expect(find.text('~/projects'), findsOneWidget);
      expect(find.text('~/code'), findsOneWidget);
      expect(find.text('Ordner hinzufuegen'), findsOneWidget);
    });

    testWidgets('shows empty state when no dirs', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInMaterial(
          ScanDirsStep(
            scanDirs: const [],
            onAddDir: () {},
            onRemoveDir: (_) {},
          ),
        ),
      );

      expect(find.text('Noch keine Ordner ausgewaehlt'), findsOneWidget);
    });
  });

  group('ProjectPreviewStep', () {
    testWidgets('shows scanning indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInMaterial(
          const ProjectPreviewStep(projectNames: [], isScanning: true),
        ),
      );

      expect(find.text('Suche Projekte...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows project names', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInMaterial(
          const ProjectPreviewStep(
            projectNames: ['Projekt Alpha', 'Projekt Beta'],
            isScanning: false,
          ),
        ),
      );

      expect(find.text('Projekt Alpha'), findsOneWidget);
      expect(find.text('Projekt Beta'), findsOneWidget);
    });

    testWidgets('shows empty state when no projects found', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInMaterial(
          const ProjectPreviewStep(projectNames: [], isScanning: false),
        ),
      );

      expect(
        find.text(
          'Keine Projekte gefunden. Du kannst spaeter Projekte importieren.',
        ),
        findsOneWidget,
      );
    });
  });
}
