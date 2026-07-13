import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/data/services/project_organization_seed_service.dart';

void main() {
  late AppDatabase db;
  late ProjectOrganizationSeedService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ProjectOrganizationSeedService(db);
  });

  tearDown(() async {
    await db.close();
  });

  ProjectModel makeProject(String folderId) {
    return ProjectModel(
      folderId: folderId,
      displayName: folderId,
      path: '/tmp/$folderId',
      projectType: ProjectType.code,
    );
  }

  group('ProjectOrganizationSeedService', () {
    test('fresh DB seeds all three groups and assigns the found subset', () async {
      final scanned = [
        makeProject('wtv'),
        makeProject('bungertshof'),
        makeProject('feldfrisch'),
        makeProject('some-other-project'),
      ];

      await service.applyIfNeeded(scanned);

      final groups = await db.getGroups();
      expect(groups.map((g) => g.name), containsAll(['Vodafone', 'Neural AI Produkte', 'Kundenprojekte']));

      final kundenprojekteId = groups.firstWhere((g) => g.name == 'Kundenprojekte').id;
      expect(await db.getProjectGroupId('wtv'), equals(kundenprojekteId));
      expect(await db.getProjectGroupId('bungertshof'), equals(kundenprojekteId));
      expect(await db.getProjectGroupId('feldfrisch'), equals(kundenprojekteId));
      expect(await db.getProjectGroupId('some-other-project'), isNull);
    });

    test('missing folder names are skipped without throwing', () async {
      final scanned = [makeProject('wtv')];

      await expectLater(service.applyIfNeeded(scanned), completes);

      final groups = await db.getGroups();
      final kundenprojekteId = groups.firstWhere((g) => g.name == 'Kundenprojekte').id;
      expect(await db.getProjectGroupId('wtv'), equals(kundenprojekteId));
      expect(await db.getProjectGroupId('bungertshof'), isNull);
    });

    test('second applyIfNeeded call is a no-op once the flag is set', () async {
      await service.applyIfNeeded([makeProject('wtv')]);
      final groupsAfterFirst = await db.getGroups();

      // Manually move "wtv" out of Kundenprojekte to prove a second call
      // does not re-seed and re-assign it.
      await db.setProjectGroup('wtv', null);
      await service.applyIfNeeded([makeProject('wtv')]);

      final groupsAfterSecond = await db.getGroups();
      expect(groupsAfterSecond.length, equals(groupsAfterFirst.length));
      expect(await db.getProjectGroupId('wtv'), isNull);
    });

    test('pre-existing same-named group is not duplicated', () async {
      await db.createGroup('Vodafone');

      await service.applyIfNeeded([makeProject('wtv')]);

      final groups = await db.getGroups();
      expect(groups.where((g) => g.name == 'Vodafone').length, equals(1));
    });

    test('Archiv exists and is untouched by the seed', () async {
      await service.applyIfNeeded([makeProject('wtv')]);

      final groups = await db.getGroups();
      final archiv = groups.firstWhere((g) => g.isSystem);
      expect(archiv.name, equals('Archiv'));
      expect(await db.getCollapseState(archiv.id), isTrue);
    });

    test('returns true when it actually seeds, false on a no-op', () async {
      expect(await service.applyIfNeeded([makeProject('wtv')]), isTrue);
      expect(await service.applyIfNeeded([makeProject('wtv')]), isFalse);
    });

    test('overlapping calls do not create duplicate groups (race guard)', () async {
      final scanned = [makeProject('wtv')];

      final results = await Future.wait([
        service.applyIfNeeded(scanned),
        service.applyIfNeeded(scanned),
        service.applyIfNeeded(scanned),
      ]);

      expect(results.where((seeded) => seeded).length, equals(1));

      final groups = await db.getGroups();
      expect(groups.where((g) => g.name == 'Vodafone').length, equals(1));
      expect(groups.where((g) => g.name == 'Neural AI Produkte').length, equals(1));
      expect(groups.where((g) => g.name == 'Kundenprojekte').length, equals(1));
    });
  });
}
