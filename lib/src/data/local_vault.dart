import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalVault {
  LocalVault({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _preferences = preferences ?? SharedPreferencesAsync();

  static const _masterKeyName = 'p2p.local-vault.master-key.v1';
  static const _valuePrefix = 'p2p.vault.';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  final Cipher _cipher = AesGcm.with256bits();

  Future<Map<String, dynamic>?> readJson(String key) async {
    final stored = await _preferences.getString('$_valuePrefix$key');
    if (stored == null) return null;

    final envelope = jsonDecode(stored) as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(envelope['cipherText'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)),
    );
    final clearText = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(await _masterKey()),
    );
    return jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
  }

  Future<void> writeJson(String key, Map<String, Object?> value) async {
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(value)),
      secretKey: SecretKey(await _masterKey()),
      nonce: _cipher.newNonce(),
    );
    await _preferences.setString(
      '$_valuePrefix$key',
      jsonEncode({
        'cipherText': base64Encode(secretBox.cipherText),
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      }),
    );
  }

  Future<List<int>> _masterKey() async {
    final existing = await _secureStorage.read(key: _masterKeyName);
    if (existing != null) return base64Decode(existing);

    final random = Random.secure();
    final generated = List<int>.generate(32, (_) => random.nextInt(256));
    await _secureStorage.write(
      key: _masterKeyName,
      value: base64Encode(generated),
    );
    return generated;
  }
}
