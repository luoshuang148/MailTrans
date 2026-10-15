# Getting started with MailTrans

[Home](../README.md) · [简体中文](getting-started.zh-CN.md)

MailTrans 0.10 is an experimental development preview. The [release](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0) provides an ad-hoc signed app ZIP and SHA-256 file. It is **not Developer ID signed or notarized**; downloaded-app acceptance and independent Mac installation remain unverified. If macOS blocks the preview, build from source rather than disabling security controls.

## Requirements

| Component | Current requirement / verified environment |
| --- | --- |
| Hardware | Apple Silicon; the Swift worker is built for `arm64` |
| Operating system | macOS 26.4 minimum; tested on macOS 26.4 |
| Mail | Apple Mail; tested with Mail 16.0 |
| Toolchain (source builds only) | Full Xcode installed at `/Applications/Xcode.app`; tested with Xcode 26.6 and macOS SDK 26.5 |
| Build scripting (source builds only) | Python 3, plus macOS tools including `sips`, `iconutil`, and `codesign` |
| Translation models | Apple's source-language → Simplified Chinese model; an initial download may be needed |

The app itself does not require Python or Xcode. Source builds use the selected `DEVELOPER_DIR` or `xcode-select` toolchain; `--developer-dir PATH` is also supported. Command Line Tools alone are not the documented full-app build environment. A newer operating system or toolchain meeting the minimum version does not imply that it has been tested.

## Build from source

```sh
git clone https://github.com/luoshuang148/MailTrans.git
cd MailTrans
python3 outputs/mail-translation-probe/source/build.py
```

The script runs seven native suites (core, app, extension, lifecycle, process runner, management, setup), a cross-process preferences check, and a model-status protocol check, then compiles and ad-hoc signs the application, extension, translation worker, and helpers. It verifies the generated package's signature.

Output: `outputs/mail-translation-probe/MailTrans.app`. Intermediate files are kept in the ignored `work/mail-real/` directory. The build does not install the app, enable the Mail extension, download models, or install a LaunchAgent. Build success is separate from live translation and Mail rendering verification.

## Install and enable

For an existing installation, follow [Update](#update) first.

1. Download the app ZIP and its matching `.sha256` file from the [development release](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0). In the download folder, check `shasum -a 256 -c MailTrans-0.10.0-macos-arm64-development.zip.sha256`, then extract the ZIP with Archive Utility. Source builders can use their generated app instead.
2. Move `MailTrans.app` to `/Applications` and open that copy. Do not enable automatic launch from Downloads or a temporary/translocated path. The development signature checks integrity, not publisher identity. If macOS blocks launch, report the exact message or build from source; do not disable system-wide protections.
3. First-run **MailTrans 设置** (Setup) works even with Mail closed. Use **打开“邮件”** to open Mail, then go to **Mail → Settings → Extensions** and enable **MailTrans**. The setup registration check cannot prove that Mail's enable checkbox is on; confirm it there.
4. Check the English→Chinese model status. **准备英中语言包** opens Apple's native model preparation; initial preparation may require a download. Cancelling preserves the original message.
5. Optionally enable **随“邮件”自动启动和退出**. This installs only MailTrans's per-user watcher; it does not need Python. Click **完成设置** to finish. Reopen this window anytime through **设置与帮助…** in the menu bar.
6. Use **打开示例邮件** to check the synthetic sample. Compare automatic translation, **显示原文** and **翻译为中文**, as well as the table, embedded image, and link. Exact wording can vary with Apple's model.

If the installed extension is missing, an advanced registration check is:

```sh
pluginkit -a '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
codesign --verify --deep --strict '/Applications/MailTrans.app'
```

Restart Mail and confirm the extension checkbox afterward. Ad-hoc signature verification does not replace notarization or cross-machine testing.

MailKit's permission dialog may mention reading all email and modifying outgoing messages. MailTrans implements reading-view translation; it does not send/forward messages or rewrite mailbox originals. It does not require Accessibility, AppleScript automation, or Full Disk Access.

## Everyday use

- **English message:** opens into an automatic translation after a short wait. Cached translations display faster.
- **Chinese translation:** **显示原文** switches to the original, retaining its content and a separate control strip.
- **Original view:** **翻译为中文** switches back. Choosing the original prevents a pending automatic result from replacing it during the cache's lifetime.
- **Original Chinese message:** stays untouched, with no injected controls. Detection uses body text, including a conservative rule for Chinese-first replies.
- **Other source languages:** click **翻译为中文** manually; support depends on Apple's available language pair.
- **Automatic translation:** toggle **自动翻译英文邮件** in the menu. This defaults to on, remembers your choice, and keeps manual translation and cached switching available while paused.
- **Cancel/retry:** **取消当前翻译** cancels the running translation; **重试上次失败的邮件** retries that exact cached message. An expired cache asks you to reopen the message. Translation workers time out after 120 seconds and keep the original.
- **Status:** an error icon and hover text report failures; pause uses a pause icon. Other menu actions clear cache, reload the visible Mail message, open **设置与帮助…**, or quit.

## Optional automatic launch

Enable/disable the option in **设置与帮助…**. The existing CLI remains available for developers; from the repository root, after installing the app:

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py enable
python3 outputs/mail-translation-probe/source/manage_lifecycle.py status
```

This installs a per-user LaunchAgent at `~/Library/LaunchAgents/local.codex.mailtranslationprobe.lifecycle.plist`. An invisible `MailTransLifecycle` process observes running applications and waits for Mail. The main menu bar app starts when Mail starts and exits when Mail quits; closing a Mail window does not count as quitting. Manually opening MailTrans while Mail is closed keeps setup available.

Manually quitting MailTrans keeps it stopped for the current Mail session, even if the watcher restarts. Reopening Mail in a new session resumes automatic launch. You can also open MailTrans manually to resume immediately.

To disable automatic launch:

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py disable
```

Disabling removes the watcher service; disable the Mail extension separately if you want to stop translation entirely.

## Update

1. In settings, uncheck automatic launch (or use the developer `disable` command above), if enabled.
2. Uncheck MailTrans in Mail's extension settings, quit Mail, and quit MailTrans from its menu. Wait for its processes to exit.
3. Keep a backup of the old app outside `/Applications`. Download/check/extract the new development ZIP, or update the checkout and rebuild using `build.py`.
4. Unregister the old installed extension and the build copy before replacing the installed app:

   ```sh
   pluginkit -r '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
   pluginkit -r "$PWD/outputs/mail-translation-probe/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex"
   ```

   A copy that was never registered may have nothing to remove.
5. Replace `/Applications/MailTrans.app` with the new build; verify its signature and register the installed extension using the commands in [Install and enable](#install-and-enable).
6. Open Mail, then open `/Applications/MailTrans.app` and enable the extension. Re-enable automatic launch if desired. Restart Mail if it still loads the old extension, then repeat the synthetic message check.

Never replace an app bundle while its extension or helpers are still running.

## Cache and privacy

Cache location:

```text
~/Library/Containers/local.codex.mailtranslationprobe.extension/Data/Library/Caches/MailTranslation
```

It contains temporary original message copies (possibly including attachments), translated reading content, and original/translated view state. It is not the mailbox or Apple's model storage. MailTrans does not upload this cache to a translation service.

The cache holds at most 20 messages. Entries expire after 30 minutes without use; cleanup runs every minute while the app is running. Normal exit clears the cache. Forced termination can leave files until the next run. Directory permissions are `0700`, file permissions are `0600`, and cache keys, hashes, and symbolic links are validated.

Clear it using **清空本地缓存**. A Mail refresh can immediately cache the open original again. Mail's own local data and backups are managed separately. Remote images keep following Mail's existing privacy and content-loading settings.

## Uninstall

For the native flow, quit Mail, then reopen MailTrans if it followed Mail's quit. Open **设置与帮助… → 卸载 MailTrans…**, review the exact app path, and confirm. The app stops its watcher, unregisters its extension, trashes only that app, and clears its translation cache. Cancelling does nothing. If stopping the watcher or unregistering fails, the app is retained and an error is shown.

For manual removal:

1. Clear the local cache from MailTrans's menu.
2. Disable the watcher in settings or with `manage_lifecycle.py disable` before deleting the app. Keep the checkout until the CLI step is complete.
3. Disable the MailTrans extension in Mail settings, quit Mail, and quit MailTrans.
4. Unregister the installed extension with the `pluginkit -r` command above, then move `/Applications/MailTrans.app` to the Trash.
5. If cache remains after a forced exit, remove only the `MailTranslation` cache directory shown above while Mail and MailTrans are stopped.

This does not remove mailbox messages or Apple language models.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No extension listed | Install the `/Applications` copy and register its `.appex`; restart Mail, then open MailTrans. Check the minimum OS version. |
| English remains untranslated | Enable the extension and run MailTrans. Prepare the language pair manually, then use **重新加载当前邮件**. Check that the email is not signed/encrypted or over the limits in the README. |
| `model_missing` | Prepare the correct language pair through the native prompt, then retry. The same worker has returned different results in a synced Documents build path and an installed `/Applications` path; the cause remains unresolved. |
| A signature error mentions FinderInfo/resource forks | Build outside iCloud/other synchronized folders and copy a fresh build. The build removes only signing-incompatible metadata from generated bundles; synchronized folders can add it again. Re-run signature verification. |
| macOS blocks the app | This is an ad-hoc signed development build, not a notarized distribution. Include the exact warning and environment in a compatibility report. |
| No translation button on a Chinese email | Expected: original Chinese bodies bypass the extension, including Chinese-first replies with English quotes or signatures. |
| Missing remote images | Check Mail's own remote-content settings and the image source. MailTrans does not override those settings. |
| Watcher is running after quitting Mail | Expected: the invisible watcher waits for the next Mail launch. Use `disable` to remove it. |
| MailTrans stays stopped after manual quit | Expected for the current Mail session. Open MailTrans manually or quit and relaunch Mail. |

To validate the installed worker independently after preparing models:

```sh
python3 outputs/mail-translation-probe/source/verify_worker.py '/Applications/MailTrans.app/Contents/MacOS/TranslationWorker'
```

This tests real local translation, ordering, Chinese preservation, and error cases. It does not verify Mail's interface rendering. If an issue remains, use the [issue forms](https://github.com/luoshuang148/MailTrans/issues/new/choose) with a synthetic reproduction and sanitized output.
