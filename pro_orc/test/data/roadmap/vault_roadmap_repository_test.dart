import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/roadmap/vault_roadmap_repository.dart';

/// Creates a real temp directory shaped like `~/N3URAL-Vault`, with a
/// `projects/<slug>/` subtree mirroring the 7-type IA (`spec/`, `plans/`,
/// `records/`) — mirrors the `a1_reader_test.dart` real-temp-dir
/// convention (no mocks).
Future<Directory> _createTempVault() async {
  return Directory.systemTemp.createTemp('roadmap_vault_');
}

Future<Directory> _createProjectDir(Directory vaultRoot, String slug) async {
  final dir = Directory(p.join(vaultRoot.path, 'projects', slug));
  await dir.create(recursive: true);
  return dir;
}

Future<void> _writeSpec(
  Directory projectDir,
  String fileName,
  String content,
) async {
  final specDir = Directory(p.join(projectDir.path, 'spec'));
  await specDir.create(recursive: true);
  await File(p.join(specDir.path, fileName)).writeAsString(content);
}

Future<void> _writePlan(
  Directory projectDir,
  String fileName,
  String content,
) async {
  final plansDir = Directory(p.join(projectDir.path, 'plans'));
  await plansDir.create(recursive: true);
  await File(p.join(plansDir.path, fileName)).writeAsString(content);
}

void main() {
  group('ObsidianVaultRoadmapRepository', () {
    test(
      'resolves spec + matching plan into a milestone with one phase per spec',
      () async {
        final vaultRoot = await _createTempVault();
        addTearDown(() => vaultRoot.delete(recursive: true));

        final projectDir = await _createProjectDir(vaultRoot, 'pro-orc');
        await _writeSpec(projectDir, '001-roadmap-backlog-dashboard.md', '''
---
title: "Roadmap & Backlog Dashboard in Pro Orc"
status: implementing
---

# Roadmap & Backlog Dashboard in Pro Orc
''');
        await _writePlan(
          projectDir,
          '001-roadmap-backlog-dashboard-wave-plan.md',
          '''
---
spec_path: /some/path.md
---

# Wave Plan
''',
        );

        final repo = ObsidianVaultRoadmapRepository(
          vaultRootPath: vaultRoot.path,
        );
        final result = await repo.resolve('pro-orc', '/irrelevant/local/path');

        expect(result.source, RoadmapSource.vault);
        expect(result.data.isEmpty, isFalse);
        expect(result.data.milestones, hasLength(1));

        final milestone = result.data.milestones.single;
        expect(milestone.phases, hasLength(1));

        final phase = milestone.phases.single;
        expect(phase.name, 'Roadmap & Backlog Dashboard in Pro Orc');
        expect(phase.status, 'implementing');
        expect(phase.specs, hasLength(2));
        expect(
          phase.specs.map((s) => s.title),
          contains('Roadmap & Backlog Dashboard in Pro Orc'),
        );
        expect(
          phase.specs.map((s) => s.title),
          contains('001-roadmap-backlog-dashboard-wave-plan'),
        );
      },
    );

    test(
      'returns empty RoadmapData when the project directory is missing',
      () async {
        final vaultRoot = await _createTempVault();
        addTearDown(() => vaultRoot.delete(recursive: true));

        final repo = ObsidianVaultRoadmapRepository(
          vaultRootPath: vaultRoot.path,
        );
        final result = await repo.resolve('does-not-exist', '/irrelevant');

        expect(result.data.isEmpty, isTrue);
        expect(result.source, RoadmapSource.vault);
      },
    );

    test(
      'returns empty RoadmapData when spec/ directory has no files',
      () async {
        final vaultRoot = await _createTempVault();
        addTearDown(() => vaultRoot.delete(recursive: true));

        await _createProjectDir(vaultRoot, 'empty-project');

        final repo = ObsidianVaultRoadmapRepository(
          vaultRootPath: vaultRoot.path,
        );
        final result = await repo.resolve('empty-project', '/irrelevant');

        expect(result.data.isEmpty, isTrue);
        expect(result.source, RoadmapSource.vault);
      },
    );

    test(
      'never throws for a slug mismatch against a nonexistent vault root',
      () async {
        final repo = ObsidianVaultRoadmapRepository(
          vaultRootPath: '/definitely/does/not/exist/vault',
        );
        final result = await repo.resolve('some-slug', '/irrelevant');

        expect(result.data.isEmpty, isTrue);
        expect(result.source, RoadmapSource.vault);
      },
    );

    test(
      'handles a spec with missing/malformed frontmatter without throwing',
      () async {
        final vaultRoot = await _createTempVault();
        addTearDown(() => vaultRoot.delete(recursive: true));

        final projectDir = await _createProjectDir(vaultRoot, 'broken-project');
        await _writeSpec(
          projectDir,
          '002-broken.md',
          '# No frontmatter here at all\n',
        );

        final repo = ObsidianVaultRoadmapRepository(
          vaultRootPath: vaultRoot.path,
        );
        final result = await repo.resolve('broken-project', '/irrelevant');

        expect(result.data.isEmpty, isFalse);
        final phase = result.data.milestones.single.phases.single;
        expect(phase.name, '002-broken');
        expect(phase.status, 'unknown');
      },
    );
  });

  group('FallbackRoadmapRepository integration with real Vault tier', () {
    test(
      'resolves vault data end-to-end when local and brain tiers are empty',
      () async {
        final vaultRoot = await _createTempVault();
        addTearDown(() => vaultRoot.delete(recursive: true));

        final projectDir = await _createProjectDir(
          vaultRoot,
          'integration-slug',
        );
        await _writeSpec(projectDir, '003-feature.md', '''
---
title: "Integration Feature"
status: clarified
---
''');

        final vaultRepo = ObsidianVaultRoadmapRepository(
          vaultRootPath: vaultRoot.path,
        );
        final result = await vaultRepo.resolve(
          'integration-slug',
          '/irrelevant',
        );

        expect(result.source, RoadmapSource.vault);
        expect(result.data.isEmpty, isFalse);
      },
    );
  });
}
