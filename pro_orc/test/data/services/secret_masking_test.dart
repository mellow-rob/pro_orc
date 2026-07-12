import 'package:test/test.dart';

import 'package:pro_orc/data/services/secret_masking.dart';

void main() {
  group('maskValue', () {
    test('reveals only last 4 chars for values >= 8 chars', () {
      expect(maskValue('supersecretvalue'), '••••alue');
    });

    test('fully masks values shorter than 8 chars', () {
      expect(maskValue('short'), '••••');
    });

    test('leaves empty value empty', () {
      expect(maskValue(''), '');
    });
  });

  group('maskEnvValue', () {
    test('masks secret-looking keys (case-insensitive)', () {
      expect(maskEnvValue('OPENAI_API_KEY', 'sk-1234567890abcd'), '••••abcd');
      expect(maskEnvValue('my_token', 'abcdefgh1234'), '••••1234');
      expect(maskEnvValue('DB_PASSWORD', 'hunter2hunter2'), '••••ter2');
    });

    test('leaves harmless keys untouched', () {
      expect(maskEnvValue('CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS', '1'), '1');
      expect(maskEnvValue('LOG_LEVEL', 'debug'), 'debug');
    });
  });

  group('maskSecrets', () {
    test('masks query params whose name looks like a secret', () {
      final out = maskSecrets(
        'https://api.example.test/mcp?api_key=abcdefgh1234&x=1',
      );
      expect(out, contains('api_key=%E2%80%A2%E2%80%A2%E2%80%A2%E2%80%A21234'));
      // Non-secret param stays intact.
      expect(out, contains('x=1'));
    });

    test('masks userinfo password in a URL', () {
      final out = maskSecrets('https://user:supersecret@host.test/path');
      expect(out, contains('user:'));
      expect(out, isNot(contains('supersecret')));
    });

    test('masks value following a secret-looking flag (space form)', () {
      final out = maskSecrets('mcp-server --api-key abcdefgh1234 --port 3000');
      expect(out, 'mcp-server --api-key ••••1234 --port 3000');
    });

    test('masks value in --flag=value form', () {
      final out = maskSecrets('node srv.js --token=abcdefgh1234');
      expect(out, 'node srv.js --token=••••1234');
    });

    test('leaves a harmless command line unchanged', () {
      const cmd = 'node server.js --port 8080 --verbose';
      expect(maskSecrets(cmd), cmd);
    });

    test('leaves a plain URL without secrets unchanged', () {
      const url = 'https://example.test/mcp';
      expect(maskSecrets(url), url);
    });
  });
}
