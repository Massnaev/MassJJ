import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.downloadUrl,
    required this.assetName,
    required this.sizeBytes,
    required this.sha256,
  });

  final String version;
  final Uri downloadUrl;
  final String assetName;
  final int sizeBytes;
  final String sha256;
}

class GithubUpdateClient {
  GithubUpdateClient({HttpClient? client}) : _client = client ?? HttpClient();

  static final latestReleaseUri = Uri.https(
    'api.github.com',
    '/repos/Massnaev/MassJJ/releases/latest',
  );
  static const expectedAssetName = 'MassJJ-android.apk';
  static const _maxMetadataBytes = 1024 * 1024;
  static const _maxApkBytes = 250 * 1024 * 1024;

  final HttpClient _client;

  Future<AppUpdateRelease?> checkForUpdate({
    required String currentVersion,
  }) async {
    final request = await _client
        .getUrl(latestReleaseUri)
        .timeout(const Duration(seconds: 8));
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    request.headers.set(HttpHeaders.userAgentHeader, 'MassJJ/$currentVersion');
    request.headers.set('X-GitHub-Api-Version', '2026-03-10');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'GitHub release check failed: ${response.statusCode}',
      );
    }
    final bytes = await _readBounded(
      response,
      maxBytes: _maxMetadataBytes,
      timeout: const Duration(seconds: 8),
    );
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('Invalid release data.');
    return parseLatestRelease(
      Map<String, Object?>.from(decoded),
      currentVersion: currentVersion,
    );
  }

  Future<File> download(
    AppUpdateRelease release, {
    required Directory directory,
    required void Function(double progress) onProgress,
  }) async {
    if (release.downloadUrl.scheme != 'https') {
      throw const FormatException('Update asset must use HTTPS.');
    }
    if (release.sizeBytes <= 0 || release.sizeBytes > _maxApkBytes) {
      throw const FormatException('Update asset has an invalid size.');
    }
    await directory.create(recursive: true);
    final partial = File(
      '${directory.path}${Platform.pathSeparator}MassJJ-update.apk.part',
    );
    final completed = File(
      '${directory.path}${Platform.pathSeparator}MassJJ-update.apk',
    );
    if (await partial.exists()) await partial.delete();

    IOSink? output;
    try {
      final response = await _openHttpsDownload(release.downloadUrl);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Update download failed: ${response.statusCode}');
      }
      final advertisedLength = response.contentLength;
      if (advertisedLength >= 0 && advertisedLength != release.sizeBytes) {
        await response.drain<void>();
        throw const FormatException('Update size does not match release data.');
      }

      output = partial.openWrite();
      final hashSink = Sha256().newHashSink();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        received += chunk.length;
        if (received > release.sizeBytes || received > _maxApkBytes) {
          throw const FormatException(
            'Update download is larger than expected.',
          );
        }
        hashSink.add(chunk);
        output.add(chunk);
        onProgress(received / release.sizeBytes);
      }
      await output.flush();
      await output.close();
      output = null;
      hashSink.close();
      if (received != release.sizeBytes) {
        throw const FormatException('Update download is incomplete.');
      }
      final actualDigest = _hex((await hashSink.hash()).bytes);
      if (actualDigest != release.sha256) {
        throw const FormatException('Update SHA-256 verification failed.');
      }
      if (await completed.exists()) {
        await completed.delete();
      }
      return await partial.rename(completed.path);
    } catch (_) {
      await output?.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<HttpClientResponse> _openHttpsDownload(Uri initial) async {
    var current = initial;
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (current.scheme != 'https') {
        throw const FormatException('Update redirect must use HTTPS.');
      }
      final request = await _client
          .getUrl(current)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'MassJJ updater');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) {
        return response;
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) {
        throw const FormatException('Invalid update redirect.');
      }
      current = current.resolve(location);
    }
    throw const FormatException('Too many update redirects.');
  }

  void close() => _client.close(force: true);

  static AppUpdateRelease? parseLatestRelease(
    Map<String, Object?> json, {
    required String currentVersion,
  }) {
    final tag = json['tag_name'];
    final assets = json['assets'];
    if (tag is! String || assets is! List) return null;
    final version = _normalizedVersion(tag);
    if (version == null || compareVersions(version, currentVersion) <= 0) {
      return null;
    }

    Map<String, Object?>? asset;
    for (final value in assets) {
      if (value is Map && value['name'] == expectedAssetName) {
        asset = Map<String, Object?>.from(value);
        break;
      }
    }
    if (asset == null) return null;
    final rawUrl = asset['browser_download_url'];
    final rawSize = asset['size'];
    final rawDigest = asset['digest'];
    if (rawUrl is! String || rawSize is! int || rawDigest is! String) {
      return null;
    }
    final url = Uri.tryParse(rawUrl);
    final digestMatch = RegExp(
      r'^sha256:([0-9a-fA-F]{64})$',
    ).firstMatch(rawDigest);
    if (url == null ||
        url.scheme != 'https' ||
        url.host.toLowerCase() != 'github.com' ||
        rawSize <= 0 ||
        rawSize > _maxApkBytes ||
        digestMatch == null) {
      return null;
    }
    return AppUpdateRelease(
      version: version,
      downloadUrl: url,
      assetName: expectedAssetName,
      sizeBytes: rawSize,
      sha256: digestMatch.group(1)!.toLowerCase(),
    );
  }

  static int compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    if (leftParts == null || rightParts == null) {
      throw const FormatException('Invalid semantic version.');
    }
    for (var index = 0; index < 3; index++) {
      final comparison = leftParts[index].compareTo(rightParts[index]);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  static String? _normalizedVersion(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$',
    ).firstMatch(value);
    if (match == null) return null;
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  static List<int>? _versionParts(String value) {
    final normalized = _normalizedVersion(value);
    return normalized?.split('.').map(int.parse).toList(growable: false);
  }

  static Future<List<int>> _readBounded(
    Stream<List<int>> stream, {
    required int maxBytes,
    required Duration timeout,
  }) async {
    final bytes = <int>[];
    await for (final chunk in stream.timeout(timeout)) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Response is too large.');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  static String _hex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
