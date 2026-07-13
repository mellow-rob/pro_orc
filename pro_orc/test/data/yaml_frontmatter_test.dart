import 'package:test/test.dart';

import 'package:pro_orc/data/services/claude_tools_scanner.dart';

void main() {
  group('parseYamlFrontmatter', () {
    test('parses simple scalar key: value pairs', () {
      final result = parseYamlFrontmatter('''---
name: my-agent
color: blue
---
Body content.
''');

      expect(result['name'], 'my-agent');
      expect(result['color'], 'blue');
    });

    test('strips surrounding double quotes', () {
      final result = parseYamlFrontmatter('''---
description: "A quoted description."
---
''');

      expect(result['description'], 'A quoted description.');
    });

    test(
      'handles values containing colons by splitting only at the first colon',
      () {
        final result = parseYamlFrontmatter('''---
description: Deploy to https://example.com:8080/path
---
''');

        expect(
          result['description'],
          'Deploy to https://example.com:8080/path',
        );
      },
    );

    test('folds a ">" block scalar into a single space-joined line', () {
      final result = parseYamlFrontmatter('''---
description: >
  Transforms a raw feature idea into a structured entry.
  Produces: frontmatter, Overview, Key Features.
  MUST trigger when: user says "neue Feature-Idee".
name: feature-idea
---
''');

      expect(
        result['description'],
        'Transforms a raw feature idea into a structured entry. '
        'Produces: frontmatter, Overview, Key Features. '
        'MUST trigger when: user says "neue Feature-Idee".',
      );
      expect(result['name'], 'feature-idea');
    });

    test('preserves newlines in a "|" literal block scalar', () {
      final result = parseYamlFrontmatter('''---
description: |
  Line one.
  Line two.
name: falk
---
''');

      expect(result['description'], 'Line one.\nLine two.');
      expect(result['name'], 'falk');
    });

    test(
      'a key after a block scalar is parsed correctly (dedent ends the block)',
      () {
        final result = parseYamlFrontmatter('''---
description: >
  Multi-line text
  continues here.
model: opus
color: purple
---
''');

        expect(result['description'], 'Multi-line text continues here.');
        expect(result['model'], 'opus');
        expect(result['color'], 'purple');
      },
    );

    test('returns empty map for content with no frontmatter delimiters', () {
      final result = parseYamlFrontmatter(
        '# Just a heading\nNo frontmatter here.',
      );
      expect(result, isEmpty);
    });

    test('ignores lines without a colon inside frontmatter', () {
      final result = parseYamlFrontmatter('''---
name: test
this line has no colon-ish thing? nope it does actually
---
''');

      expect(result['name'], 'test');
    });
  });
}
