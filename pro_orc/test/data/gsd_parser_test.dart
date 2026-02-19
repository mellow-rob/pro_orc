import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/gsd_parser.dart';

/// Creates a temp project directory with an optional .planning/ subdir
/// and writes the provided files into it. Returns the root project path.
Future<Directory> createTempProject(Map<String, String> files) async {
  final tmp = await Directory.systemTemp.createTemp('gsd_parser_test_');
  for (final entry in files.entries) {
    final file = File('${tmp.path}/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
  }
  return tmp;
}

void main() {
  group('GsdParser', () {
    // ------------------------------------------------------------------ //
    // Non-GSD project (no .planning/)
    // ------------------------------------------------------------------ //
    test('returns empty result when no .planning/ directory exists', () async {
      final tmp = await Directory.systemTemp.createTemp('gsd_parser_no_planning_');
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.isEmpty, isTrue);
      expect(result.displayName, isNull);
      expect(result.description, isNull);
      expect(result.hasParseError, isFalse);
    });

    // ------------------------------------------------------------------ //
    // Missing STATE.md — partial result, no error
    // ------------------------------------------------------------------ //
    test('returns partial result when STATE.md is missing', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '# MyProject\n\n## What This Is\n\nA cool tool.\n',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.currentPhase, isNull);
      expect(result.gsd.status, isNull);
      expect(result.displayName, equals('MyProject'));
      expect(result.hasParseError, isFalse);
    });

    // ------------------------------------------------------------------ //
    // STATE.md — bold field format
    // ------------------------------------------------------------------ //
    test('extracts phase, status, nextStep from bold **Field:** format', () async {
      final tmp = await createTempProject({
        '.planning/STATE.md': '''
## Current Position

**Phase:** 3 of 5 (API Layer)
**Status:** building
**Next Step:** Implement auth endpoints
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.currentPhase, equals('3 of 5 (API Layer)'));
      expect(result.gsd.status, equals('building'));
      expect(result.gsd.nextStep, equals('Implement auth endpoints'));
    });

    // ------------------------------------------------------------------ //
    // STATE.md — plain field format
    // ------------------------------------------------------------------ //
    test('extracts phase and status from plain "Field:" format', () async {
      final tmp = await createTempProject({
        '.planning/STATE.md': '''
Phase: 2 of 4 (Setup)
Status: planning
Next Step: Write tests
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.currentPhase, equals('2 of 4 (Setup)'));
      expect(result.gsd.status, equals('planning'));
      expect(result.gsd.nextStep, equals('Write tests'));
    });

    // ------------------------------------------------------------------ //
    // STATE.md — German field names
    // ------------------------------------------------------------------ //
    test('extracts next step from German **Nächster Schritt:** field', () async {
      final tmp = await createTempProject({
        '.planning/STATE.md': '''
**Phase:** 1 of 3 (Research)
**Status:** research
**Nächster Schritt:** Daten analysieren
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.nextStep, equals('Daten analysieren'));
    });

    // ------------------------------------------------------------------ //
    // STATE.md — **Next Action:** variant
    // ------------------------------------------------------------------ //
    test('extracts next step from **Next Action:** variant', () async {
      final tmp = await createTempProject({
        '.planning/STATE.md': '''
**Status:** paused
**Next Action:** Resume after holidays
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.nextStep, equals('Resume after holidays'));
      expect(result.gsd.status, equals('paused'));
    });

    // ------------------------------------------------------------------ //
    // deriveStatus normalization
    // ------------------------------------------------------------------ //
    test('deriveStatus normalizes raw status strings', () async {
      final cases = {
        'In Progress': 'building',
        'IN PROGRESS': 'building',
        'building': 'building',
        'Planning': 'planning',
        'Research': 'research',
        'Paused': 'paused',
        'Done': 'done',
        'Archived': 'archived',
        'complete': 'done',
        'finished': 'done',
      };

      for (final entry in cases.entries) {
        final tmp = await createTempProject({
          '.planning/STATE.md': 'Status: ${entry.key}\n',
        });
        addTearDown(() => tmp.delete(recursive: true));

        final result = await parseGsdData(tmp.path);
        expect(
          result.gsd.status,
          equals(entry.value),
          reason: '"${entry.key}" should normalize to "${entry.value}"',
        );
      }
    });

    // ------------------------------------------------------------------ //
    // ROADMAP.md — plan progress calculation
    // ------------------------------------------------------------------ //
    test('calculates plan progress from ROADMAP.md checkbox patterns', () async {
      final tmp = await createTempProject({
        '.planning/ROADMAP.md': '''
## Plans

- [x] 01-01-PLAN setup
- [x] 01-02-PLAN models
- [x] 02-01-PLAN api
- [ ] 02-02-PLAN auth
- [ ] 03-01-PLAN ui
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      // 3 done / 5 total = 60%
      expect(result.gsd.plansCompleted, equals(3));
      expect(result.gsd.plansTotal, equals(5));
      expect(result.gsd.phaseProgress, equals(60));
    });

    // ------------------------------------------------------------------ //
    // ROADMAP.md — uppercase [X] checkbox
    // ------------------------------------------------------------------ //
    test('counts uppercase [X] as done in ROADMAP.md', () async {
      final tmp = await createTempProject({
        '.planning/ROADMAP.md': '''
- [X] 01-01-PLAN first
- [x] 01-02-PLAN second
- [ ] 01-03-PLAN third
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.plansCompleted, equals(2));
      expect(result.gsd.plansTotal, equals(3));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — H1 heading → displayName
    // ------------------------------------------------------------------ //
    test('extracts H1 heading as displayName from PROJECT.md', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '# My Awesome Project\n\nSome content.\n',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.displayName, equals('My Awesome Project'));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — Notion URL extraction
    // ------------------------------------------------------------------ //
    test('extracts Notion URL from HTML comment in PROJECT.md', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Project

<!-- notion: https://www.notion.so/workspace/page-abc123 -->

Content.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.notionUrl, equals('https://www.notion.so/workspace/page-abc123'));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — description from "## What This Is"
    // ------------------------------------------------------------------ //
    test('extracts description from ## What This Is heading', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Project

## What This Is

A **fantastic** tool that does everything.

## Other Section

Other content.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.description, equals('A fantastic tool that does everything.'));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — description from "## Core Value"
    // ------------------------------------------------------------------ //
    test('extracts description from ## Core Value heading', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Project

## Core Value

Provides instant project visibility.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.description, equals('Provides instant project visibility.'));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — description from German headings
    // ------------------------------------------------------------------ //
    test('extracts description from ## Kernwert heading', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Projekt

## Kernwert

Das Wichtigste auf einen Blick.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.description, equals('Das Wichtigste auf einen Blick.'));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — description truncated to 200 chars
    // ------------------------------------------------------------------ //
    test('truncates description to 200 characters', () async {
      final longText = 'A' * 300;
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Project

## What This Is

$longText
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.description!.length, equals(200));
    });

    // ------------------------------------------------------------------ //
    // PROJECT.md — bold markers stripped from description
    // ------------------------------------------------------------------ //
    test('strips bold markers from description', () async {
      final tmp = await createTempProject({
        '.planning/PROJECT.md': '''
# Project

## What This Is

A **bold** statement about **greatness**.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.description, equals('A bold statement about greatness.'));
    });

    // ------------------------------------------------------------------ //
    // Full extraction — all files present with all fields
    // ------------------------------------------------------------------ //
    test('extracts all fields when all files are present', () async {
      final tmp = await createTempProject({
        '.planning/STATE.md': '''
## Current Position

**Phase:** 7 of 11 (Data Layer)
**Status:** building
**Next Step:** Implement parser
''',
        '.planning/ROADMAP.md': '''
- [x] 07-01-PLAN models
- [x] 07-02-PLAN parser
- [ ] 07-03-PLAN git
- [ ] 07-04-PLAN repo
''',
        '.planning/PROJECT.md': '''
# Project Orchestrator

<!-- notion: https://notion.so/page-123 -->

## What This Is

The best project dashboard ever.

## Other

Other content.
''',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.currentPhase, equals('7 of 11 (Data Layer)'));
      expect(result.gsd.status, equals('building'));
      expect(result.gsd.nextStep, equals('Implement parser'));
      expect(result.gsd.plansCompleted, equals(2));
      expect(result.gsd.plansTotal, equals(4));
      expect(result.gsd.phaseProgress, equals(50));
      expect(result.gsd.notionUrl, equals('https://notion.so/page-123'));
      expect(result.displayName, equals('Project Orchestrator'));
      expect(result.description, equals('The best project dashboard ever.'));
      expect(result.hasParseError, isFalse);
    });

    // ------------------------------------------------------------------ //
    // All files missing (empty .planning/)
    // ------------------------------------------------------------------ //
    test('returns empty GsdData when .planning/ exists but all files missing', () async {
      final tmp = await createTempProject({
        '.planning/.keep': '',
      });
      addTearDown(() => tmp.delete(recursive: true));

      final result = await parseGsdData(tmp.path);

      expect(result.gsd.isEmpty, isTrue);
      expect(result.displayName, isNull);
      expect(result.description, isNull);
      expect(result.hasParseError, isFalse);
    });
  });
}
