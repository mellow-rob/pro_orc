import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_organization_seed_service.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/groups_provider.dart';
import 'package:pro_orc/providers/project_group_membership_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

ProjectModel _project(String folderId) {
  return ProjectModel(
    folderId: folderId,
    displayName: folderId,
    path: '/tmp/$folderId',
    projectType: ProjectType.code,
  );
}

void main() {
  group('F-007 — first-launch seed/group-read race', () {
    test(
      'reading groupsProvider/membershipProvider right after projectsProvider'
      ' resolves for the first time already sees the seeded groups and'
      ' assignments — no app restart or extra I/O needed',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final scanned = [
          _project('wtv'),
          _project('bungertshof'),
          _project('some-other-project'),
        ];

        // A small artificial delay on the seed step stands in for real disk
        // I/O (DB writes + scan), giving a UI that reads groupsProvider/
        // membershipProvider "at the same time" as projectsProvider a
        // realistic chance to observe the pre-seed state — exactly the
        // window F-007 is about.
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            // Stands in for the real scan + watcher wiring: performs the
            // exact same organization-seed step projectsProvider runs in
            // production (lib/providers/projects_provider.dart), against a
            // fixed scanned-project list instead of a real filesystem scan.
            projectsProvider.overrideWith((ref) async {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              await ProjectOrganizationSeedService(db).applyIfNeeded(scanned);
              return scanned;
            }),
          ],
        );
        addTearDown(container.dispose);

        // Mirror a widget tree that watches groups/membership alongside the
        // project list on the very first frame — i.e. BEFORE
        // projectsProvider has resolved, not after. This is what actually
        // races the seed in production (ShellScreen-style consumers read
        // groupedProjectsProvider, which watches all three). The returned
        // subscriptions must be held (not discarded) — they are what keeps
        // these non-keepAlive notifiers alive across the await below,
        // exactly like a mounted widget's `ref.watch` would.
        final groupsSub = container.listen(groupsProvider, (_, _) {});
        final membershipSub = container.listen(membershipProvider, (_, _) {});
        addTearDown(groupsSub.close);
        addTearDown(membershipSub.close);

        // The only synchronization point a real first-launch UI has: await
        // projectsProvider's first resolution once.
        await container.read(projectsProvider.future);
        // Let the now-unblocked _loadFromDb() awaits (groupsProvider's and
        // membershipProvider's own `await ref.watch(projectsProvider.future)`
        // followed by their DB read) finish draining — this is ordinary
        // event-loop settling, the same thing a widget gets for free from
        // Flutter's own pump between frames, not a reintroduced race.
        await Future<void>.delayed(Duration.zero);

        final groupNames = container
            .read(groupsProvider)
            .map((g) => g.name)
            .toSet();
        expect(
          groupNames,
          containsAll(['Vodafone', 'Neural AI Produkte', 'Kundenprojekte']),
          reason:
              'groupsProvider must already reflect the seeded groups once '
              'projectsProvider has resolved once — no app restart needed',
        );

        final kundenprojekteId = container
            .read(groupsProvider)
            .firstWhere((g) => g.name == 'Kundenprojekte')
            .id;

        final membership = container.read(membershipProvider);
        expect(membership['wtv'], equals(kundenprojekteId));
        expect(membership['bungertshof'], equals(kundenprojekteId));
        expect(membership.containsKey('some-other-project'), isFalse);
      },
    );
  });
}
