<div align="center">
  <img src="outputs/mail-translation-probe/assets/mail-translation-icon.png" width="112" alt="MailTrans app icon">
  <h1>MailTrans</h1>
  <p><strong>Read English emails in Chinese. Stay in Apple Mail.</strong></p>
  <p>A macOS MailKit extension powered by Apple's on-device Translation framework.</p>
  <p>
    <img src="https://img.shields.io/badge/version-0.10-2563eb" alt="Version 0.10">
    <img src="https://img.shields.io/badge/macOS-26.4%2B-111827" alt="macOS 26.4 or later">
    <img src="https://img.shields.io/badge/architecture-Apple%20Silicon-111827" alt="Apple Silicon">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-16a34a" alt="MIT license"></a>
    <img src="https://img.shields.io/badge/status-experimental-f59e0b" alt="Experimental">
  </p>
  <p><strong>English</strong> · <a href="README.zh-CN.md">简体中文</a></p>
  <p><a href="https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0">Pre-release</a> · <a href="docs/getting-started.md">Getting started</a> · <a href="CHANGELOG.md">Changelog</a> · <a href="https://github.com/luoshuang148/MailTrans/issues/new/choose">Report an issue</a> · <a href="CONTRIBUTING.md">Contribute</a></p>
</div>

![Illustrated MailTrans workflow using synthetic email content; not an application screenshot](docs/assets/mailtrans-overview.svg)

MailTrans translates email body text into **Simplified Chinese** inside Apple Mail's reading view. English emails translate automatically, and you can switch back to the original with one click. MailTrans uses Apple's local translation models and keeps the original mailbox message intact.

> **Development pre-release.** Download the app ZIP and SHA-256 checksum from [v0.10.0](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0), or build from source. The app is ad-hoc signed and **not notarized**; macOS may block downloaded copies. Tested locally on Apple Silicon / macOS 26.4. Independent Mac installation remains unverified. See the [setup guide](docs/getting-started.md) and [compatibility checklist](docs/compatibility.md).

## Features

| Feature | What to expect |
| --- | --- |
| Automatic English → Chinese | Open an English email; translation runs in the background without a separate reading window. |
| One-click original | **显示原文** shows the original; **翻译为中文** returns to the translation. Cached translations switch without running the model again. |
| Chinese stays untouched | Original Simplified and Traditional Chinese emails receive no translation controls or replacement content. Chinese-first replies are preserved even with English signatures or quotes. |
| Layout preservation | Keeps HTML structure, tables, links, inline images, and attachment bytes where supported. Translated text can naturally change wrapping and column widths. |
| On-device translation | Uses Apple Translation with downloaded language models; there is no cloud translation provider or automatic cloud fallback. |
| Menu bar controls and setup | Pause automatic translation, cancel a task, retry the last failure, and open setup/help. An optional watcher follows Mail launch/quit. |

First-run setup works with Mail closed. Translation tasks have a 120-second timeout; cancellation and late-result protection preserve original content. Pausing automatic translation persists across launches and keeps manual translation available.

The current translation target and interface controls are Chinese. Other source languages can be translated manually when supported by Apple's installed language models.

## Getting started

For the development app, download and extract the ZIP, move `MailTrans.app` to `/Applications`, and open it. First-run setup explains Mail activation, extension settings, language models, and optional automatic launch. See the [installation guide](docs/getting-started.md#install-and-enable).

To build from source, you need **Apple Silicon, macOS 26.4 or later, full Xcode at `/Applications/Xcode.app`, and Python 3**. The verified build environment uses Xcode 26.6 / macOS SDK 26.5; other toolchains are unverified.

```sh
git clone https://github.com/luoshuang148/MailTrans.git
cd MailTrans
python3 outputs/mail-translation-probe/source/build.py
```

The build runs the native test suites, packages the extension and helpers, and creates an ad-hoc signed `outputs/mail-translation-probe/MailTrans.app`. It does **not** install the app or enable background services.

Follow the [installation guide](docs/getting-started.md#install-and-enable) to place the app in `/Applications`, enable the Mail extension, and prepare language models. Please read the update steps first if MailTrans is already installed.

## How it works

1. A **MailKit reading extension** receives a message and preserves its original MIME content in a temporary local cache. Original Chinese messages bypass this path.
2. The **menu bar app** selects translatable body text and sends it to a **Swift translation worker** using Apple's on-device Translation framework.
3. The extension displays the translated reading content in Mail. **显示原文** restores the original content with a separate control strip; MailTrans does not write changes back to the mailbox.

See [architecture and source map](docs/architecture.md) for MIME handling, request cancellation, and the optional Mail lifecycle watcher.

## Privacy and local data

- MailTrans has no cloud translation API, API key configuration, or telemetry. Language model preparation may require a download from Apple.
- The temporary cache can contain original message content **including attachments**, translations, and view state. It is stored in the extension's local container, not in the repository.
- Cache limits: **20 messages**, expiry after **30 minutes without use**, periodic cleanup while running, and clearing on normal app exit. After forced termination, cleanup happens on the next run.
- **清空本地缓存** clears MailTrans's cache; it does not delete mailbox messages or downloaded language models. Mail may cache the currently open message again after a refresh.
- Remote images follow **Apple Mail's existing privacy settings**. Local translation does not make remote email content offline.

Read [cache details](docs/getting-started.md#cache-and-privacy) and the [security reporting policy](SECURITY.md). Use synthetic messages when reporting issues; never upload real email or cache files.

## Current limitations

- Translates body text only. Subjects, sender headers, image text, attachment contents, and code blocks are not translated.
- Signed/encrypted messages and messages that cannot be parsed safely are skipped. Limits are 10 MB per original message, 10,000 characters per text node, and 200,000 translatable characters per message.
- Short labels, specialized terms, and mixed-language messages may be imperfect. Compare with the original when needed.
- Translation runs one message at a time. Failed automatic tasks retain the original; manual retry is available.
- Intel Macs and older macOS releases are unsupported. Developer ID signing, notarization, and independent Mac installation have not been completed for this preview.

## Help and contribute

Check the [troubleshooting guide](docs/getting-started.md#troubleshooting), [open issues](https://github.com/luoshuang148/MailTrans/issues), or submit a [bug report / feature request](https://github.com/luoshuang148/MailTrans/issues/new/choose). Reports in English or Chinese are welcome.

Contributions to documentation, synthetic test cases, accessibility, compatibility testing, and the translation pipeline are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions and validation expectations.

## License

[MIT](LICENSE) © 2026 MailTrans contributors. MailTrans is an independent project and is not affiliated with or endorsed by Apple.
