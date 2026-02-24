import 'package:flutter_test/flutter_test.dart';
import 'package:pro_orc/data/services/notion_crypto.dart';

void main() {
  group('notion_crypto', () {
    test('encrypt then decrypt returns original string', () {
      const original = 'secret-api-key-abc123';
      final encrypted = encryptNotionKey(original);
      final decrypted = decryptNotionKey(encrypted);
      expect(decrypted, equals(original));
    });

    test('empty string encrypt returns empty string', () {
      expect(encryptNotionKey(''), equals(''));
    });

    test('encrypted output is NOT equal to plaintext input', () {
      const original = 'secret-api-key-abc123';
      final encrypted = encryptNotionKey(original);
      expect(encrypted, isNot(equals(original)));
    });

    test('decrypt of garbage string returns empty string', () {
      expect(decryptNotionKey('not-valid-base64-!!!garbage!!!'), equals(''));
    });
  });
}
