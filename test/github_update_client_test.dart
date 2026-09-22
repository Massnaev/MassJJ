import 'package:flutter_test/flutter_test.dart';
import 'package:p2p_messenger/src/core/update/github_update_client.dart';

void main() {
  test('accepts a newer signed GitHub APK asset', () {
    final release = GithubUpdateClient.parseLatestRelease({
      'tag_name': 'v0.2.0',
      'assets': [
        {
          'name': 'MassJJ-android.apk',
          'browser_download_url':
              'https://github.com/Massnaev/MassJJ/releases/download/v0.2.0/MassJJ-android.apk',
          'size': 1024,
          'digest': 'sha256:${List.filled(32, 'ab').join()}',
        },
      ],
    }, currentVersion: '0.1.0');

    expect(release, isNotNull);
    expect(release!.version, '0.2.0');
    expect(release.sha256, List.filled(32, 'ab').join());
  });

  test('rejects an update without the expected APK digest', () {
    final release = GithubUpdateClient.parseLatestRelease({
      'tag_name': 'v0.2.0',
      'assets': [
        {
          'name': 'MassJJ-android.apk',
          'browser_download_url':
              'https://github.com/Massnaev/MassJJ/releases/download/v0.2.0/MassJJ-android.apk',
          'size': 1024,
        },
      ],
    }, currentVersion: '0.1.0');

    expect(release, isNull);
  });

  test('compares semantic versions numerically', () {
    expect(
      GithubUpdateClient.compareVersions('0.10.0', '0.9.9'),
      greaterThan(0),
    );
    expect(GithubUpdateClient.compareVersions('1.0.0', '1.0.0+7'), 0);
    expect(GithubUpdateClient.compareVersions('1.2.2', '1.2.10'), lessThan(0));
  });
}
