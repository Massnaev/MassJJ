import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/identity/identity_service.dart';
import 'package:p2p_messenger/src/data/local_vault.dart';

void main() {
  group('IdentityService', () {
    test('creates and reloads one stable local identity', () async {
      final vault = _MemoryVault();
      final service = IdentityService(vault);

      expect(await service.hasIdentity(), isFalse);
      final created = await service.create();
      final loaded = await service.load();
      final createdAgain = await service.create();

      expect(await service.hasIdentity(), isTrue);
      expect(loaded.userId, created.userId);
      expect(loaded.privateSeed, created.privateSeed);
      expect(loaded.inboxReadToken, created.inboxReadToken);
      expect(createdAgain.userId, created.userId);
      expect(createdAgain.privateSeed, created.privateSeed);
    });

    test('restores the same identity and mailbox capabilities', () async {
      final original = await IdentityService(_MemoryVault()).create();
      final restored = await IdentityService(
        _MemoryVault(),
      ).restore(original.recoveryCode);

      expect(restored.userId, original.userId);
      expect(restored.publicKey, original.publicKey);
      expect(restored.privateSeed, original.privateSeed);
      expect(restored.inboxReadToken, original.inboxReadToken);
      expect(restored.inboxWriteToken, original.inboxWriteToken);
    });

    test('rejects a malformed recovery code', () async {
      final service = IdentityService(_MemoryVault());

      await expectLater(
        service.restore('p2pr1.not-a-valid-bundle'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _MemoryVault implements JsonVault {
  final Map<String, Map<String, Object?>> _values = {};

  @override
  Future<Map<String, dynamic>?> readJson(String key) async {
    final value = _values[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> writeJson(String key, Map<String, Object?> value) async {
    _values[key] = Map<String, Object?>.from(value);
  }
}
