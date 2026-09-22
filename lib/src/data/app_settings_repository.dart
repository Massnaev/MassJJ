import 'local_vault.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._vault);

  static const _settingsKey = 'settings.v1';
  final JsonVault _vault;

  Future<String?> loadRelayUrl() async {
    final stored = await _vault.readJson(_settingsKey);
    if (stored == null || !stored.containsKey('relayUrl')) return null;
    final value = stored['relayUrl'];
    return value is String ? value : null;
  }

  Future<void> saveRelayUrl(String value) {
    return _vault.writeJson(_settingsKey, {'relayUrl': value});
  }
}
