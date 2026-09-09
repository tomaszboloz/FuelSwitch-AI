# Signed automatic updates

The application reads `main/appcast.xml`, not GitHub's latest-release API. Publishing a tag alone does not make a release installable by Sparkle.

## Release checklist

1. Increment `CFBundleShortVersionString` and the integer `CFBundleVersion` in `Resources/Info.plist`. Do not reuse a build number.
2. Update `RELEASE_NOTES.md`. Run `swift test --parallel`, `python3 -m unittest discover -s scripts -p 'test_*.py'`, and `make app`.
3. Commit, create an annotated tag matching the short version (`vX.Y.Z`), and push the commit and tag.
4. Wait for **all** Release steps, including publication of the appcast. A visible GitHub release is not sufficient proof that the update channel has advanced.
5. Check that the live feed advertises the expected build and that its archive length/signature match the released ZIP.

## Signing and packaging

The repository's Actions secret `SPARKLE_PRIVATE_KEY` contains the existing Sparkle Ed25519 signing key. It must match `SUPublicEDKey` in already-installed apps. Never rotate this key casually: old applications cannot trust a replacement public key merely because a new release bundles it. Never commit the private key or put it in logs.

The workflow uses `ditto -c -k --sequesterRsrc --keepParent`, extracts the resulting ZIP, and runs strict, deep `codesign` verification. Do not replace this with `zip -r`: that dereferences framework symlinks and breaks the signed bundle. `scripts/update_feed.py` checks those links too.

Sparkle signs the final ZIP bytes. `scripts/verify_update.swift` checks that signature against the public key from the extracted app. Checksums and provenance describe the same archive. Do not repackage or overwrite published artifacts after signing.

The feed is also attached to the release. After publishing the assets, the workflow downloads the public ZIP and compares it byte-for-byte, then promotes the feed to `main` using the Actions bot. This needs repository `contents: write` permission; branch rules must allow this bot commit. If that step fails, fix the permission/conflict and rerun the release publication job. Do not point the feed at an unsigned or missing ZIP.

`promote` is idempotent and does not roll back a newer build if an older job finishes later. An equal build number with different release metadata is rejected. Concurrent releases are serialized.

## App behavior

Automatic checking and downloading remain opt-in in Settings. Preferences are applied before Sparkle starts. Both manual buttons perform a fresh feed check and offer Sparkle installation when a newer release exists. A manual network/HTTP/parse failure is an error, never confirmation that the application is current. Sparkle verifies and installs the archive and manages relaunch/quit-time behavior.

The current distribution is ad-hoc code-signed, not Developer ID signed or Apple-notarized. Archive authenticity is protected by the existing Sparkle EdDSA key; fresh downloads may still need macOS Gatekeeper approval.
