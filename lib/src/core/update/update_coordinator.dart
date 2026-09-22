import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'github_update_client.dart';

class AndroidUpdateBridge {
  const AndroidUpdateBridge();

  static const _channel = MethodChannel('app.massjj/updates');

  Future<AndroidUpdateInfo?> loadInfo() async {
    if (!Platform.isAndroid) return null;
    final raw = await _channel.invokeMapMethod<String, Object?>('getInfo');
    if (raw == null) return null;
    final version = raw['version'];
    final directory = raw['directory'];
    if (version is! String || directory is! String) return null;
    return AndroidUpdateInfo(version: version, directory: Directory(directory));
  }

  Future<String> install(File apk) async {
    final result = await _channel.invokeMethod<String>('installApk', apk.path);
    return result ?? 'installer';
  }
}

class AndroidUpdateInfo {
  const AndroidUpdateInfo({required this.version, required this.directory});

  final String version;
  final Directory directory;
}

class UpdateCoordinator extends ChangeNotifier {
  UpdateCoordinator({
    GithubUpdateClient? client,
    AndroidUpdateBridge bridge = const AndroidUpdateBridge(),
    bool enabled = true,
  }) : _client = client ?? GithubUpdateClient(),
       _bridge = bridge,
       _enabled = enabled;

  factory UpdateCoordinator.disabled() => UpdateCoordinator(enabled: false);

  final GithubUpdateClient _client;
  final AndroidUpdateBridge _bridge;
  final bool _enabled;

  AppUpdateRelease? available;
  bool checking = false;
  bool installing = false;
  double progress = 0;
  String? userMessage;
  bool _disposed = false;
  DateTime? _lastCheckAt;

  Future<void> check({bool force = false}) async {
    if (!_enabled || checking || installing) return;
    final now = DateTime.now().toUtc();
    final lastCheckAt = _lastCheckAt;
    if (!force &&
        lastCheckAt != null &&
        now.difference(lastCheckAt) < const Duration(minutes: 15)) {
      return;
    }
    _lastCheckAt = now;
    checking = true;
    _notify();
    try {
      final info = await _bridge.loadInfo();
      if (info == null) return;
      available = await _client.checkForUpdate(currentVersion: info.version);
    } catch (_) {
      // Update checks must never prevent messaging or expose network internals.
    } finally {
      checking = false;
      _notify();
    }
  }

  Future<void> installAvailable() async {
    final release = available;
    if (!_enabled || release == null || installing) return;
    installing = true;
    progress = 0;
    userMessage = null;
    _notify();
    try {
      final info = await _bridge.loadInfo();
      if (info == null) {
        throw StateError('Обновление доступно только на Android.');
      }
      final apk = await _client.download(
        release,
        directory: info.directory,
        onProgress: (value) {
          progress = value.clamp(0.0, 1.0).toDouble();
          _notify();
        },
      );
      final action = await _bridge.install(apk);
      userMessage = action == 'settings'
          ? 'Разрешите установку из MassJJ и нажмите «Обновить» ещё раз.'
          : 'Подтвердите обновление в системном установщике.';
    } catch (_) {
      userMessage = 'Не удалось скачать или проверить обновление.';
    } finally {
      installing = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}
