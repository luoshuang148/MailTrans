# MailTrans 0.11 original-first reading and freeze-fix validation

Environment: macOS 26.4 / Apple Silicon arm64 / Xcode 26.6 (17F113) / macOS SDK 26.5. App version 0.11 / build 11; deployment floor remains 26.4.

## Behavior changes

- English messages now stay in Mail's original view by default. Automatic English translation still prepares and caches the Chinese reading view, but writes it without activation and does not ask Mail to reload.
- An explicit **翻译为中文** click activates the cached translation and reloads the message. **显示原文** removes activation while keeping the cached translation, so switching back does not rerun Apple's model.
- Cached state is split into original, translatable-source and activated-translation markers. The translatable marker also prevents a stale translated cache from bypassing the Chinese-original path.
- No cloud provider, cloud fallback, telemetry or notarization was added.

## Freeze and refresh fixes

- Recent-message scans no longer read every original and translation in full. Bounded file attributes now drive cache listings and view state, with synchronized cache mutations. The 20-message / 5 MB fixture check fell from about 432 ms to 6.7 ms; reopening one cached message took about 6.4 ms.
- A parsed MIME tree is reused within a message request, and stale text segments are cleared before each render. The 20-message / 4.6 MB synthetic parse run took 3.576 seconds total.
- Automatic cache scanning runs on a serial background queue. The host no longer parses or hashes a full message on the main thread before starting translation, and it only activates Mail when Mail is not already frontmost.
- When Mail reloads an already-active translation, the extension returns the cached display before MIME parsing or language detection. Mail can still briefly redraw its reading view because `reloadVisibleMessages` remains the supported switch mechanism.
- Worker shutdown now bounds pipe draining when a grandchild keeps stdout open and places a hard deadline after SIGKILL. A real child-process regression covers the inherited-stdout case.

## Local verification

- `python3 -m unittest discover -s outputs/mail-translation-probe/source -p 'test_*.py' -v`: 15 tests passed.
- `python3 outputs/mail-translation-probe/source/build.py`: seven native suites, cross-process preferences, model-status protocol and full compilation passed; deep/strict ad-hoc signature verification passed.
- `CoreTests` cover first-write change reporting, unchanged reopen, cheap source/translation state, hidden automatic display, explicit activation, restore-original-with-cache, and missing-source repair.
- `AppTests` verify that automatic translation remains cached but hidden while manual translation still activates.
- `ExtensionTests` verify the original view remains first after an automatic result, then uses the cached Chinese view after activation, including the active-display fast path.
- `ProcessRunnerTests` verify that a grandchild holding stdout open cannot hang the runner.

## Packaging and installed app

- The Documents build path was again given FinderInfo by the file provider, so strict packaging there failed. A copy in a non-synchronized temporary directory passed `xattr -cr`, deep/strict signature verification, ZIP creation, checksum verification and verification of the extracted app.
- Development ZIP: `MailTrans-0.11.0-macos-arm64-development.zip`
- SHA-256: `b5642d97ea6d8485c022f92082e302c664469fdf6b4c797069fd657af6b866da`
- The installed `/Applications/MailTrans.app` reports 0.11 / build 11. Its host, lifecycle helper, worker and extension binaries match the packaged build by SHA-256; the 0.11 extension is registered.
- The installed worker passed the real English→Chinese translation check, ordered batches, Chinese preservation, provider selection and invalid-input checks.
- Previous installation backup: `work/mail-real/installed-v010-before-v011.app`. That path is ignored local state, not part of the release.

## Limits

- A human click-through in the real Mail window for this revision was not performed. The host and extension process launched from `/Applications`, but default-original display, switching position and perceived flash still require live acceptance.
- Mail may still redraw when the reading view reloads. The fast path removes redundant MIME parsing and model work, not Mail's reload itself.
- No Developer ID identity, notarization, downloaded-app Gatekeeper acceptance or independent physical-Mac installation was added.
- Signed/encrypted messages, attachment contents, image text, subjects and code blocks remain outside the translation scope.
