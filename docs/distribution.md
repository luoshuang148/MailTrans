# Development distribution

MailTrans 0.11.2 (build 13) is an Apple Silicon development preview for macOS 26.4 or newer. The downloadable `MailTrans-0.11.2-macos-arm64-development.zip` contains an **ad-hoc signed, unnotarized** app. Ad-hoc verification checks integrity; it does not establish an Apple Developer identity or promise that Gatekeeper will accept a downloaded copy. No paid Apple Developer membership is needed to build this preview locally. Cross-Mac installation and Mail extension acceptance require separate testing.

## Build and verify

From the repository root on an Apple Silicon Mac with full Xcode and macOS SDK 26.5 or newer:

```sh
python3 -m unittest discover -s Sources -p 'test_*.py' -v
python3 Sources/build.py
python3 Sources/package_release.py --output-dir work/release
cd work/release
shasum -a 256 -c MailTrans-0.11.2-macos-arm64-development.zip.sha256
```

The build uses `DEVELOPER_DIR` when set, otherwise the `xcode-select` selection. An explicit override is also supported:

```sh
python3 Sources/build.py --developer-dir /Applications/Xcode.app/Contents/Developer
```

To run the native regressions independently of Swift Translation SDK/model availability:

```sh
python3 Sources/build.py --native-tests-only
```

Native test executables target the runner's macOS version; the shipping app, helper and extension retain a 26.4 deployment floor. Test commands have a 90-second execution limit and report failures, including lifecycle or GUI-session failures. This mode compiles no Swift helper and neither installs models nor reads real Mail messages. A full build also runs native regressions, compiles the app and workers, signs the nested components and verifies the complete signature. Records are written under `work/mail-real/`; successful compilation does not imply a live translation or UI acceptance result.

## Archive contract

The packager takes an existing app with `--app PATH` and a destination with `--output-dir PATH`. It never installs, signs, uploads or publishes. It validates all bundle identifiers, version/build numbers, deployment floors, required files, executable permissions and arm64 macOS Mach-O targets. It rejects unexpected bundle content and symlinks that leave the app. Only the app and its intentional synthetic `layout-sample.eml` are archived; source, work directories, translation caches, private messages and Finder metadata are excluded. An unexpected file is a failure rather than something silently included.

ZIP entries preserve executable modes and internal relative symlinks. ZIP timestamps and ordering are normalized, so unchanged app bytes and modes yield the same archive; separate compilations are not claimed to be byte-for-byte reproducible. The packager verifies the input signature, writes a temporary ZIP, extracts that exact ZIP with modes and links restored, and validates the extracted bundle/signature before replacing the output archive and writing its SHA-256 file. A failed validation produces no new release archive. Use the matching ZIP/checksum pair from one successful run.

After downloading, verify the published checksum before opening the app. Keep the ZIP intact when transferring it; GitHub's artifact wrapper may alter loose-file permissions, while the app permissions remain inside this ZIP. Use the macOS Archive Utility to extract it. Build from source if the downloaded development preview is blocked; these instructions do not disable Gatekeeper or remove quarantine.

## CI and release procedure

[GitHub Actions](../.github/workflows/ci.yml) runs portable tests on Ubuntu and native regressions, the full app build, signature verification and packaging on the hosted `macos-26` ARM runner. The [official runner image manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md), checked on 2026-10-15, lists macOS 26.6.2, default Xcode 26.6 and macOS SDK 26.5. The build checks the actual selected SDK and fails clearly if unsuitable. [Checkout](https://github.com/actions/checkout) and [artifact upload](https://github.com/actions/upload-artifact) use their official v7 majors. Workflow permissions are read-only; CI needs no signing credentials and does not publish releases.

Before publishing a development pre-release:

1. Check the source revision, intended tag and passing CI run; keep earlier release tags unchanged.
2. Run the compatibility checklist and record actual coverage and outstanding checks.
3. Package the final signed app and verify the checksum. Do not modify the app afterward.
4. Attach only the matching ZIP/checksum and write the ad-hoc/unnotarized warning prominently in release notes.
5. Download the published assets, compare checksums and verify the extracted app signature again.

## Optional future Developer ID distribution

This is a separate release process requiring an existing local Developer ID Application identity, paid membership and an existing `notarytool` keychain profile. Neither the build nor CI creates, requests or uploads certificates, passwords or API keys. The current development packager does not notarize an app or create a notarized release.

For an authorized future release, use your existing identity and keychain profile locally. Set `MAILTRANS_SIGNING_IDENTITY` and `MAILTRANS_NOTARY_PROFILE` to their local names, then sign from the inside out:

```sh
codesign --force --timestamp --options runtime --sign "$MAILTRANS_SIGNING_IDENTITY" --entitlements work/mail-real/extension.entitlements outputs/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex
codesign --force --timestamp --options runtime --sign "$MAILTRANS_SIGNING_IDENTITY" outputs/MailTrans.app/Contents/Helpers/LanguageSetup.app
codesign --force --timestamp --options runtime --sign "$MAILTRANS_SIGNING_IDENTITY" outputs/MailTrans.app/Contents/MacOS/TranslationWorker
codesign --force --timestamp --options runtime --sign "$MAILTRANS_SIGNING_IDENTITY" outputs/MailTrans.app/Contents/MacOS/MailTransLifecycle
codesign --force --timestamp --options runtime --sign "$MAILTRANS_SIGNING_IDENTITY" outputs/MailTrans.app
codesign --verify --deep --strict --verbose=2 outputs/MailTrans.app
mkdir -p work/notary
ditto -c -k --keepParent outputs/MailTrans.app work/notary/MailTrans-submission.zip
xcrun notarytool submit work/notary/MailTrans-submission.zip --keychain-profile "$MAILTRANS_NOTARY_PROFILE" --wait
xcrun stapler staple outputs/MailTrans.app
xcrun stapler validate outputs/MailTrans.app
spctl --assess --type execute --verbose=2 outputs/MailTrans.app
```

Check the submission result and log; stapling or assessment failures must stop release. Stapling changes the app bytes, so create and verify a fresh final archive/checksum afterward with a distinct notarized release name. Test the downloaded, quarantined final app and Mail extension on another Mac before claiming compatibility. Successful ad-hoc development checks cannot substitute for these checks.
