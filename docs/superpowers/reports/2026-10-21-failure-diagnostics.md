# MailTrans 0.11.1 failure-diagnostics validation

Environment: macOS 26.4 / Apple Silicon arm64 / Xcode 26.6 (17F113) / macOS SDK 26.5. App version 0.11.1 / build 12; deployment floor remains 26.4.

## Problem

The 0.11 menu bar could keep a warning icon after a translation failure while the visible status belonged to another message. The existing state held only a failed cache key and a generic accessibility description. It was overwritten by later status text, was not persisted across relaunches, and did not expose the error code. A later successful retry cleared the icon, so the original failure could not be reconstructed reliably.

## Behavior changes

- Persist the last failure code, user-facing message, cache key and timestamp in the host preferences.
- On launch, restore the failure icon only when the same source still exists and the record is no more than 30 minutes old. Older records remain visible in the menu for diagnosis but do not reactivate the warning icon or retry action.
- Show **上次失败：…（HH:mm）** in the menu with the error code in its help tag, and include the reason in the status-item tooltip.
- Add **忽略上次失败提示**, which clears only the diagnostic, not the cached mail. A successful retry of the same cache key or clearing the cache also clears it.
- Write the failure code and a 10-character cache-key prefix to `os_log` subsystem `local.codex.mailtranslationprobe`, category `translation`. Message content and full cache keys are not logged.
- No translation-provider, model-download, cloud-fallback or telemetry changes were made.

## Local verification

- `python3 -m unittest discover -s outputs/mail-translation-probe/source -p 'test_*.py' -v`: 15 tests passed.
- `python3 outputs/mail-translation-probe/source/build.py`: seven native suites, cross-process preferences, model-status protocol and full compilation passed; deep/strict ad-hoc signature verification passed.
- `AppTests` now checks persisted code/message/key, the disabled failure menu item, the dismissal action, restoration in a separate host instance, clearing after a successful retry, and dismissal without cache deletion.
- `/usr/bin/log show --last 3m --predicate 'subsystem == "local.codex.mailtranslationprobe"'` showed entries such as `translation failed code=timeout cache_key=4155502099`; no message bodies were present.

## Installed app check

- A backup of the previous 0.11 installation was saved at `work/mail-real/installed-v011-before-v0111.app`; host preferences were exported before testing and restored afterward.
- `/Applications/MailTrans.app` reports 0.11.1 / build 12. Its host binary matches the packaged build by SHA-256, and `pluginkit` lists the 0.11.1 extension as enabled at the installed path.
- A synthetic persisted failure for an existing cache key was injected before launch. The status item exposed `MailTrans · 请检查翻译状态`; its menu showed `上次失败：诊断测试：上次翻译失败（diagnostic_test · 10-21 02:37）`, enabled retry, and the dismissal action.
- Choosing **忽略上次失败提示** removed the persisted code, restored the normal `MailTrans` icon and removed the failure item. Automatic translation was disabled only for this check and its original preference was restored.

## Packaging

- The Documents build path was again given FinderInfo by the file provider, so strict packaging there failed. A copy in a non-synchronized temporary directory passed `xattr -cr`, deep/strict signature verification, ZIP creation, checksum verification and verification of the extracted app.
- Development ZIP: `MailTrans-0.11.1-macos-arm64-development.zip`
- SHA-256: `77010bd9646a7803bb2a09a09caa6bd6597bdd5741e82f55ede06972494dd94b`

## Hosted CI

- [GitHub Actions run 39476721720](https://github.com/luoshuang148/MailTrans/actions/runs/39476721720) passed both portable and ARM native jobs, including full build, signature verification, failure-diagnostics regressions and development packaging.
- Its `MailTrans-0.11.1-macos-arm64-development.zip` is byte-for-byte identical to the locally packaged ZIP and has the same SHA-256: `77010bd9646a7803bb2a09a09caa6bd6597bdd5741e82f55ede06972494dd94b`.

## Limits

- The 30-minute window deliberately prevents an old warning from reappearing forever; the historical menu entry is informational and cannot retry after its source cache expires.
- Live English→Chinese translation in Mail was not rerun for this version. The translation worker and extension behavior are unchanged from 0.11.0, and the installed 0.11.1 extension is registered.
- The original 0.11 failure's exact error code remains unknown. The new record captures future failures at the point they occur.
- No Developer ID identity, notarization, downloaded-app Gatekeeper acceptance or independent physical-Mac installation was added.
