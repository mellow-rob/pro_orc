import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

// Static 32-byte app key and 16-byte IV derived from a hardcoded app-specific string.
// This is NOT cryptographic security against sophisticated attacks —
// it prevents the Notion API key from being visible as plaintext in the SQLite file.
final _appKey = Key(Uint8List.fromList(
  utf8.encode('ProOrcNotionKeyV1__2026_Rob_Bld!').sublist(0, 32),
));
final _iv = IV(Uint8List.fromList(
  utf8.encode('ProOrcIV_2026!!!').sublist(0, 16),
));

final _encrypter = Encrypter(AES(_appKey, mode: AESMode.cbc));

/// Encrypts [plainKey] using AES-CBC and returns a base64-encoded ciphertext.
/// Returns an empty string if [plainKey] is empty.
String encryptNotionKey(String plainKey) {
  if (plainKey.isEmpty) return '';
  try {
    final encrypted = _encrypter.encrypt(plainKey, iv: _iv);
    return encrypted.base64;
  } catch (_) {
    return '';
  }
}

/// Decrypts [encryptedKey] (base64-encoded AES-CBC ciphertext) back to plaintext.
/// Returns an empty string if [encryptedKey] is empty or on any decryption failure.
String decryptNotionKey(String encryptedKey) {
  if (encryptedKey.isEmpty) return '';
  try {
    final encrypted = Encrypted.fromBase64(encryptedKey);
    return _encrypter.decrypt(encrypted, iv: _iv);
  } catch (_) {
    return '';
  }
}
