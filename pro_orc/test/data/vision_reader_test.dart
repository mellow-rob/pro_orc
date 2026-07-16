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
