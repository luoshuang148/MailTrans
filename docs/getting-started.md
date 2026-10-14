# Getting started with MailTrans

[Home](../README.md) · [简体中文](getting-started.zh-CN.md)

MailTrans 0.9 is an experimental source-build application. Cross-machine installation has not been verified, and no signed/notarized download is currently published.

## Requirements

| Component | Current requirement / verified environment |
| --- | --- |
| Hardware | Apple Silicon; the Swift worker is built for `arm64` |
| Operating system | macOS 26.4 minimum; tested on macOS 26.4 |
| Mail | Apple Mail; tested with Mail 16.0 |
| Toolchain | Full Xcode installed at `/Applications/Xcode.app`; tested with Xcode 26.6 and macOS SDK 26.5 |
| Build scripting | Python 3, plus macOS tools including `sips`, `iconutil`, and `codesign` |
| Translation models | Apple's source-language → Simplified Chinese model; an initial download may be needed |

Command Line Tools alone are not the documented build environment. A newer operating system or toolchain meeting the minimum version does not imply that it has been tested.

## Build from source

```sh
git clone https://github.com/luoshuang148/MailTrans.git
cd MailTrans
python3 outputs/mail-translation-probe/source/build.py
```

The script runs `CoreTests`, `AppTests`, `ExtensionTests`, `LifecycleTests`, and a cross-process preferences check, then compiles and ad-hoc signs the application, extension, translation worker, and helpers. It verifies the generated package's signature.

Output: `outputs/mail-translation-probe/MailTrans.app`. Intermediate files are kept in the ignored `work/mail-real/` directory. The build does not install the app, enable the Mail extension, download models, or install a LaunchAgent. Build success is separate from live translation and Mail rendering verification.

## Install and enable

For an existing installation, follow [Update](#update) first.

1. Quit Mail before installing. In Finder, copy the generated `MailTrans.app` to `/Applications`. Keep a single installed copy and run that copy rather than the build output.
2. Verify the installed package from Terminal:

   ```sh
   codesign --verify --deep --strict '/Applications/MailTrans.app'
   ```

   This checks bundle integrity; ad-hoc signing does not provide Developer ID identity or notarization. If verification fails, see [Troubleshooting](#troubleshooting).
3. Open Mail first, then open `/Applications/MailTrans.app`. The host exits immediately when Mail is not running. In **Mail → Settings → Extensions**, enable **MailTrans**. If it does not appear, register the installed extension and restart Mail:

   ```sh
   pluginkit -a '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
   ```

4. Open the included synthetic message:

   ```sh
   open -a Mail outputs/mail-translation-probe/layout-sample.eml
   ```

5. If the English → Chinese language model is missing, click **翻译为中文** (Translate to Chinese) and complete Apple's language preparation prompt. Automatic translation does not download models silently. Cancelling preparation keeps the original.
6. After models are ready, reload the message. Check automatic translation, **显示原文** (Show original), and **翻译为中文**. Check the table, embedded image, and link in both views. Exact translated wording can vary with Apple's model.

MailKit's permission dialog may mention reading all email and modifying outgoing messages. MailTrans implements reading-view translation; it does not send or forward messages, or rewrite mailbox originals. It does not require Accessibility, AppleScript automation, or Full Disk Access permissions.

The app is not notarized. If macOS blocks launch or the extension cannot be enabled, report the exact error and OS version. Do not disable system-wide security controls. Installation on a different machine remains an area for compatibility testing.

## Everyday use

- **English message:** opens into an automatic translation after a short wait. Cached translations display faster.
- **Chinese translation:** **显示原文** switches to the original, retaining its content and a separate control strip.
- **Original view:** **翻译为中文** switches back. Choosing the original prevents a pending automatic result from replacing it during the cache's lifetime.
- **Original Chinese message:** stays untouched, with no injected controls. Detection uses body text, including a conservative rule for Chinese-first replies.
- **Other source languages:** click **翻译为中文** manually; support depends on Apple's available language pair.
- **Menu bar:** **清空本地缓存** clears cache, **重新加载当前邮件** reloads the current email, and **退出 MailTrans** quits. Hover over the icon for status.

## Optional automatic launch

From the repository root, after installing the app:

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py enable
python3 outputs/mail-translation-probe/source/manage_lifecycle.py status
```

This installs a per-user LaunchAgent at `~/Library/LaunchAgents/local.codex.mailtranslationprobe.lifecycle.plist`. An invisible `MailTransLifecycle` process observes running applications and waits for Mail. The main menu bar app starts when Mail starts and exits when Mail quits; closing a Mail window does not count as quitting.

Manually quitting MailTrans keeps it stopped for the current Mail session, even if the watcher restarts. Reopening Mail in a new session resumes automatic launch. You can also open MailTrans manually to resume immediately.

To disable automatic launch:

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py disable
```

Disabling removes the watcher service; disable the Mail extension separately if you want to stop translation entirely.

## Update

1. Disable the lifecycle watcher using the command above, if enabled.
2. Uncheck MailTrans in Mail's extension settings, quit Mail, and quit MailTrans from its menu. Wait for its processes to exit.
3. Keep a backup of the old app outside `/Applications` and update the source checkout. Rebuild using `build.py`.
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

1. Clear the local cache from MailTrans's menu.
2. Disable the watcher with `manage_lifecycle.py disable` before deleting the app. Keep the checkout until this step is complete.
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
