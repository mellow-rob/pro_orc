import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:pro_orc/data/services/vision_reader.dart';

/// Creates a temp project dir with a `docs/product/` directory and returns
/// the project dir.
Future<Directory> _createTempProject() async {
  final dir = await Directory.systemTemp.createTemp('vision_proj_');
  await Directory(p.join(dir.path, 'docs', 'product')).create(recursive: true);
  return dir;
}

Future<void> _writeVisionMd(Directory project, String content) async {
  await File(
    p.join(project.path, 'docs', 'product', 'VISION.md'),
  ).writeAsString(content);
}

void main() {
  group('VisionReader — success', () {
    test('parses title, lead paragraph, and pillars', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
# Pro Orc — Vision

Pro Orc gibt dir den vollen Ueberblick ueber alle deine Projekte.

## Pillars

- **Status auf einen Blick** — Sofort erkennen, wo jedes Projekt steht.
- **Keine Ueberraschungen** — Fortschritt live statt im Nachhinein.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.title, 'Pro Orc — Vision');
      expect(
        data.lead,
        'Pro Orc gibt dir den vollen Ueberblick ueber alle deine Projekte.',
      );
      expect(data.pillars, hasLength(2));
      expect(data.pillars[0].name, 'Status auf einen Blick');
      expect(
        data.pillars[0].description,
        'Sofort erkennen, wo jedes Projekt steht.',
      );
      expect(data.pillars[1].name, 'Keine Ueberraschungen');
    });

    test('accepts en-dash and em-dash pillar separators', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
Ein kurzer Vision-Satz.

## Pillars

- **Pillar A** - Hyphen-Separator.
- **Pillar B** – En-dash-Separator.
- **Pillar C** — Em-dash-Separator.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.pillars, hasLength(3));
      expect(data.pillars.map((p) => p.name), [
        'Pillar A',
        'Pillar B',
        'Pillar C',
      ]);
    });

    test('strips a leading YAML frontmatter block', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
status: draft
---
# Titel

Der eigentliche Lead-Absatz.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.title, 'Titel');
      expect(data.lead, 'Der eigentliche Lead-Absatz.');
    });

    test(
      'strips a leading blockquote marker from the lead paragraph',
      () async {
        final project = await _createTempProject();
        addTearDown(() => project.delete(recursive: true));

        await _writeVisionMd(project, '''
# Titel

> Zitierter Vision-Satz.
''');

        final data = await VisionReader().read(project.path);

        expect(data, isNotNull);
        expect(data!.lead, 'Zitierter Vision-Satz.');
      },
    );

    test('works with no title and no pillars — lead paragraph alone is '
        'enough', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, 'Nur ein einfacher Lead-Satz ohne alles.');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.title, isNull);
      expect(data.lead, 'Nur ein einfacher Lead-Satz ohne alles.');
      expect(data.pillars, isEmpty);
    });
  });

  group('VisionReader — version (FR-002)', () {
    test('parses a quoted version from frontmatter', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
version: "2026.06 — Closed Beta"
---
# Titel

Lead-Satz.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.version, '2026.06 — Closed Beta');
    });

    test('parses an unquoted version from frontmatter', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
version: 2026.06
---
Lead-Satz.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.version, '2026.06');
    });

    test('version is null when frontmatter has no version key', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
status: draft
---
Lead-Satz.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.version, isNull);
    });

    test('version is null when there is no frontmatter block at all', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, 'Lead-Satz ganz ohne Frontmatter.');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.version, isNull);
    });

    test('version is null when frontmatter is malformed (unterminated)', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
version: "2026.06"
Lead-Satz.
''');

      final data = await VisionReader().read(project.path);

      // Unterminated frontmatter swallows the whole file, so there's no
      // lead paragraph left — the whole thing is null, not a crash.
      expect(data, isNull);
    });
  });

  group('VisionReader — links (FR-004)', () {
    test('parses multiple links, mixed web and local', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
Lead-Satz.

## Links

- [GitHub Repo](https://github.com/example/pro-orc)
- [Live App](https://pro-orc.example.com)
- [Projektordner](/Users/rob/code/pro_orc)
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.links, hasLength(3));
      expect(data.links[0].title, 'GitHub Repo');
      expect(data.links[0].target, 'https://github.com/example/pro-orc');
      expect(data.links[0].isWeb, isTrue);
      expect(data.links[1].isWeb, isTrue);
      expect(data.links[2].title, 'Projektordner');
      expect(data.links[2].target, '/Users/rob/code/pro_orc');
      expect(data.links[2].isWeb, isFalse);
    });

    test('links section absent yields an empty list', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, 'Lead-Satz ohne Links-Sektion.');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.links, isEmpty);
    });

    test('links section present with zero entries yields an empty list', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
Lead-Satz.

## Links

''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.links, isEmpty);
    });

    test('malformed link lines are skipped, not thrown', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
Lead-Satz.

## Links

- Kein Markdown-Link-Format hier.
- [Valider Link](https://example.com)
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.links, hasLength(1));
      expect(data.links.single.title, 'Valider Link');
    });
  });

  group('VisionReader — combined sections (spec canonical order)', () {
    test('parses version, pillars, AND links all together when Pillars '
        'precedes Links (regression: Pillars loop must not swallow the '
        'following ## Links section)', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
---
version: "2026.06 — Closed Beta"
---
# Pro Orc — Vision

Pro Orc gibt dir den vollen Ueberblick ueber alle deine Projekte.

## Pillars

- **Status auf einen Blick** — Sofort erkennen, wo jedes Projekt steht.
- **Keine Ueberraschungen** — Fortschritt live statt im Nachhinein.

## Links

- [GitHub Repo](https://github.com/example/pro-orc)
- [Projektordner](/Users/rob/code/pro_orc)
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.version, '2026.06 — Closed Beta');
      expect(data.pillars, hasLength(2));
      expect(data.pillars[0].name, 'Status auf einen Blick');
      expect(data.pillars[1].name, 'Keine Ueberraschungen');
      expect(data.links, hasLength(2));
      expect(data.links[0].title, 'GitHub Repo');
      expect(data.links[0].isWeb, isTrue);
      expect(data.links[1].title, 'Projektordner');
      expect(data.links[1].isWeb, isFalse);
    });
  });

  group('VisionReader — file missing', () {
    test('returns null when docs/product/VISION.md does not exist', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      final data = await VisionReader().read(project.path);

      expect(data, isNull);
    });

    test('returns null when the project path itself does not exist', () async {
      final data = await VisionReader().read(
        '/nonexistent/path/does-not-exist',
      );

      expect(data, isNull);
    });
  });

  group('VisionReader — malformed content', () {
    test('returns null for an empty file', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '');

      final data = await VisionReader().read(project.path);

      expect(data, isNull);
    });

    test('returns null for a whitespace-only file', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '   \n\n  \n');

      final data = await VisionReader().read(project.path);

      expect(data, isNull);
    });

    test('returns null when the file has only headings and no lead '
        'paragraph', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
# Titel

## Pillars

- **Pillar A** — Beschreibung.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNull);
    });

    test('malformed pillar lines (no bold marker) are silently skipped, '
        'not thrown', () async {
      final project = await _createTempProject();
      addTearDown(() => project.delete(recursive: true));

      await _writeVisionMd(project, '''
Lead-Satz.

## Pillars

- Kein Bold hier, wird ignoriert.
- **Valider Pillar** — Beschreibung.
''');

      final data = await VisionReader().read(project.path);

      expect(data, isNotNull);
      expect(data!.pillars, hasLength(1));
      expect(data.pillars.single.name, 'Valider Pillar');
    });
  });
}
