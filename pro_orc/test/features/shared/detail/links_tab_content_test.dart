import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shared/detail/links_tab_content.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Captures launch calls instead of hitting real dart:io/url_launcher — same
/// seam as `vision_links_section_test.dart`.
class _FakeQuickActionsService extends QuickActionsService {
  String? openedUrl;
  String? openedLocalPath;
  bool localPathResult = true;

  @override
  Future<void> openUrl(String url) async {
    openedUrl = url;
  }

  @override
  Future<bool> openLocalPathInFinder(String path) async {
    openedLocalPath = path;
    return localPathResult;
  }
}

void main() {
  Future<void> pumpContent(
    WidgetTester tester, {
    List<ExternalResource> resources = const [],
    List<VisionLink> manualLinks = const [],
    QuickActionsService? qa,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AppColors.dark]),
        home: Scaffold(
          body: LinksTabContent(
            resources: resources,
            manualLinks: manualLinks,
            colors: AppColors.dark,
            qa: qa ?? QuickActionsService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LinksTabContent — merge behavior', () {
    testWidgets('renders a chip for an auto-detected GitHub resource', (
      tester,
    ) async {
      await pumpContent(
        tester,
        resources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/N3URAL-A1/niimo',
            hint: 'Repository via `gh repo delete` loeschen',
          ),
        ],
      );

      expect(find.text('GitHub-Repository'), findsOneWidget);
    });

    testWidgets('auto-detected resource and a manual link with the same target '
        'produce exactly one chip (dedup by URI)', (tester) async {
      await pumpContent(
        tester,
        resources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/example/pro-orc',
            hint: 'x',
          ),
        ],
        manualLinks: const [
          VisionLink(
            title: 'GitHub Repo',
            target: 'https://github.com/example/pro-orc',
            isWeb: true,
          ),
        ],
      );

      // The auto-detected label wins; the manual duplicate is dropped.
      expect(find.text('GitHub-Repository'), findsOneWidget);
      expect(find.text('GitHub Repo'), findsNothing);
    });

    testWidgets('a manual link with a distinct target from any auto-detected '
        'resource still renders alongside it', (tester) async {
      await pumpContent(
        tester,
        resources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/example/pro-orc',
            hint: 'x',
          ),
        ],
        manualLinks: const [
          VisionLink(
            title: 'Design-Doku',
            target: 'https://example.com/design',
            isWeb: true,
          ),
        ],
      );

      expect(find.text('GitHub-Repository'), findsOneWidget);
      expect(find.text('Design-Doku'), findsOneWidget);
    });

    test('isEmpty is true only when both sources are empty', () {
      final qa = QuickActionsService();
      final bothEmpty = LinksTabContent(
        resources: const [],
        manualLinks: const [],
        colors: AppColors.dark,
        qa: qa,
      );
      final onlyResources = LinksTabContent(
        resources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/example/pro-orc',
            hint: 'x',
          ),
        ],
        manualLinks: const [],
        colors: AppColors.dark,
        qa: qa,
      );
      final onlyManual = LinksTabContent(
        resources: const [],
        manualLinks: const [
          VisionLink(
            title: 'Design-Doku',
            target: 'https://example.com/design',
            isWeb: true,
          ),
        ],
        colors: AppColors.dark,
        qa: qa,
      );

      expect(bothEmpty.isEmpty, isTrue);
      expect(onlyResources.isEmpty, isFalse);
      expect(onlyManual.isEmpty, isFalse);
    });

    testWidgets('tapping an auto-detected chip invokes the URL-launch call', (
      tester,
    ) async {
      final qa = _FakeQuickActionsService();

      await pumpContent(
        tester,
        resources: const [
          ExternalResource(
            type: ExternalResourceType.github,
            label: 'GitHub-Repository',
            uri: 'https://github.com/N3URAL-A1/niimo',
            hint: 'x',
          ),
        ],
        qa: qa,
      );

      await tester.tap(find.text('GitHub-Repository'));
      await tester.pumpAndSettle();

      expect(qa.openedUrl, 'https://github.com/N3URAL-A1/niimo');
    });
  });
}
