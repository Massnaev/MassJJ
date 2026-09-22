# Android release and in-app updates

MassJJ uses GitHub Releases as its Android distribution channel. There is no
official binary release yet. Do not publish an APK until a stable signing key is
created, backed up securely, and tested on a disposable device.

## Update contract

The installed app checks the public endpoint
`/repos/Massnaev/MassJJ/releases/latest`. A release is offered only when all of
these conditions are true:

- the tag is a higher stable semantic version such as `v0.2.0`;
- the release contains exactly named asset `MassJJ-android.apk`;
- GitHub reports a valid `sha256:` digest for that asset;
- the asset uses an HTTPS GitHub download URL and is no larger than 250 MB.

The APK is downloaded to the private app cache, size-checked, SHA-256 verified,
and passed to the Android system installer. Android still requires the user to
approve installation and, on first use, allow MassJJ as an installation source.

## Data-preserving requirements

Android preserves the encrypted vault and app preferences during an update only
when the new APK has the same application ID, a compatible signing certificate,
and a non-decreasing version code. Therefore:

1. never change `app.p2pmessenger.p2p_messenger` for an update;
2. never lose or silently replace the release signing key;
3. increment `version:` in `pubspec.yaml` for every release;
4. never tell users to uninstall the previous official version.

Changing the signing key without a valid Android signing-key rotation forces an
uninstall, which erases local messages and identity data. The existing debug-
signed development APK is not the first official release and is not guaranteed
to update into a future production-signed build.

## Local signing configuration

Create `android/key.properties` locally (it is ignored by Git) with:

```properties
storeFile=path/to/massjj-release.jks
storePassword=...
keyAlias=massjj
keyPassword=...
```

The Gradle build uses that key when all four values exist. Otherwise it falls
back to the debug key so local development builds continue to work. Never
commit the keystore or `key.properties`.

## Release checklist

1. Update `pubspec.yaml`, changelog/handoff documentation, and release notes.
2. Run `flutter analyze`, `flutter test`, relay tests when relevant, and
   `flutter build apk --release` with the release signing configuration.
3. Verify the APK signing certificate matches the previous official release.
4. Test installing the APK over the previous release without uninstalling and
   confirm identity, contacts, messages, and outbox remain readable.
5. Rename the verified artifact to `MassJJ-android.apk`.
6. Create a non-draft, non-prerelease GitHub Release tagged `vX.Y.Z` and upload
   the APK. Confirm the GitHub asset exposes a SHA-256 digest.
7. Test the in-app banner, download, digest verification, and system installer
   on at least one supported physical Android device.
