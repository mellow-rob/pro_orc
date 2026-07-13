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
  group('groupsProvider/membershipProvider — no flicker on re-emission', () {
    test(
      'F-007 stays fixed: first projectsProvider resolution already carries'
      ' the seeded groups and assignments',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final scanned = [_project('wtv'), _project('bungertshof')];

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            projectsProvider.overrideWith((ref) async {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              await ProjectOrganizationSeedService(db).applyIfNeeded(scanned);
              return scanned;
            }),
          ],
        );
        addTearDown(container.dispose);

        final groupsSub = container.listen(groupsProvider, (_, _) {});
        final membershipSub = container.listen(membershipProvider, (_, _) {});
        addTearDown(groupsSub.close);
        addTearDown(membershipSub.close);

        await container.read(projectsProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final groupNames = container
            .read(groupsProvider)
            .map((g) => g.name)
            .toSet();
        expect(
          groupNames,
          containsAll(['Vodafone', 'Neural AI Produkte', 'Kundenprojekte']),
          reason:
              'first-launch seed must still be visible right after '
              'projectsProvider resolves once (F-007)',
        );

        final kundenprojekteId = container
            .read(groupsProvider)
            .firstWhere((g) => g.name == 'Kundenprojekte')
            .id;
        final membership = container.read(membershipProvider);
        expect(membership['wtv'], equals(kundenprojekteId));
        expect(membership['bungertshof'], equals(kundenprojekteId));
      },
    );

    test(
      'a later projectsProvider re-emission never transiently empties'
      ' groupsProvider/membershipProvider state (the flicker regression)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final scanned = [_project('wtv'), _project('bungertshof')];

        // Controls how many times projectsProvider "resolves" so the test
        // can force a second, later re-emission (mirrors a watcher tick)
        // strictly after the first load + seed has already settled.
        var callCount = 0;
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            projectsProvider.overrideWith((ref) async {
              callCount++;
              if (callCount == 1) {
                await Future<void>.delayed(const Duration(milliseconds: 5));
                await ProjectOrganizationSeedService(
                  db,
                ).applyIfNeeded(scanned);
              } else {
                // Later re-emissions (watcher ticks) take a little time too,
                // to widen the window in which a buggy rebuild would show
                // transiently empty state.
                await Future<void>.delayed(const Duration(milliseconds: 5));
              }
              return scanned;
            }),
          ],
        );
        addTearDown(container.dispose);

        // Record every emitted groups/membership state so we can assert none
        // of them are empty once the first load has completed.
        final groupsStates = <List<dynamic>>[];
        final membershipStates = <Map<String, String?>>[];
        final groupsSub = container.listen(groupsProvider, (_, next) {
          groupsStates.add(next);
        });
        final membershipSub = container.listen(membershipProvider, (
          _,
          next,
        ) {
          membershipStates.add(next);
        });
        addTearDown(groupsSub.close);
        addTearDown(membershipSub.close);

        // First load + seed settles.
        await container.read(projectsProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(groupsProvider), isNotEmpty);
        expect(container.read(membershipProvider), isNotEmpty);

        final groupsStatesBeforeReemission = List.of(groupsStates);
        final membershipStatesBeforeReemission = List.of(membershipStates);

        // Simulate a watcher-driven re-emission of projectsProvider (e.g.
        // ~/.claude/projects FSEvent tick) well after the initial settle —
        // this must NOT reset groupsProvider/membershipProvider to empty.
        container.invalidate(projectsProvider);
        await container.read(projectsProvider.future);
        // Drain any follow-up microtasks the (buggy) subscription-based
        // reload would have queued.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final newGroupsStates = groupsStates
            .skip(groupsStatesBeforeReemission.length)
            .toList();
        final newMembershipStates = membershipStates
            .skip(membershipStatesBeforeReemission.length)
            .toList();

        expect(
          newGroupsStates.any((s) => s.isEmpty),
          isFalse,
          reason:
              'groupsProvider must never transiently emit an empty list '
              'after the initial load — that is the group-flicker bug',
        );
        expect(
          newMembershipStates.any((s) => s.isEmpty),
          isFalse,
          reason:
              'membershipProvider must never transiently emit an empty map '
              'after the initial load — that is the group-flicker bug',
        );

        // Final state must still reflect the seeded assignments.
        final kundenprojekteId = container
            .read(groupsProvider)
            .firstWhere((g) => g.name == 'Kundenprojekte')
            .id;
        final membership = container.read(membershipProvider);
        expect(membership['wtv'], equals(kundenprojekteId));
        expect(membership['bungertshof'], equals(kundenprojekteId));
      },
    );
  });
}
