# Changelog

User-facing changes are listed below. Version numbers describe application builds; they do not imply a published binary release. See [Git history](https://github.com/luoshuang148/MailTrans/commits/main/) for implementation details.

## v0.10.0 — Public development preview (2026-10-15)

- Add native first-run setup for Mail, extension registration guidance, model availability, and optional automatic launch. Setup remains available with Mail closed.
- Add a persistent automatic-English-translation toggle, current-task cancellation, retry of the last failed message, and visible menu icon error state.
- Bound translation workers to 120 seconds / 8 MiB output and terminate owned children during cancellation/shutdown, including SIGTERM-resistant processes.
- Add settings-based lifecycle management, GitHub update/help links, and confirmed exact-app uninstall without a Python dependency.
- Add portable packaging tests, seven native test suites, model-status checks, GitHub CI, development ZIP/checksum packaging, and a compatibility checklist.
- App remains ad-hoc signed and unnotarized; independent physical-Mac installation and live translation compatibility require separate validation.

中文：新增首次设置、暂停自动翻译、取消与失败重试、超时恢复、图形化自动联动/卸载，以及开发版 ZIP、校验文件和自动化检查。未完成分发公证与独立 Mac 验证。

## v0.9.0 — First public preview (2026-10-14)

First GitHub pre-release, distributed as source. Application version remains 0.9 / build 9. Includes the 0.9 behavior and the earlier features below.

- Add English and Chinese project pages, an illustrated workflow, installation/update/uninstall guides, and an architecture overview.
- Add contribution and security policies, issue forms, a pull request template, and the MIT license.
- Replace personal machine setup notes with general project documentation.

## 0.9 — Original Chinese messages remain untouched

- Bypass translation controls, replacement MIME, and translation-cache writes for original Simplified and Traditional Chinese bodies.
- Detect language from visible body text rather than the subject or cached translation.
- Preserve Chinese-first replies even when English signatures or quoted text are longer.
- Keep the original/translated switch for English messages translated into Chinese.

## 0.8 — MailTrans and automatic Mail lifecycle

- Rename the application and visible extension/helper labels to MailTrans.
- Add an optional per-user, event-driven background watcher to follow Mail launch and quit.
- Honor manual quit for the current Mail session, including watcher restarts.
- Cancel owned translation and language-preparation tasks and clear temporary cache on normal exit.
- Fix launch/quit races and preference sharing across the app, helper, and command-line processes.

## 0.7 — App icon and simpler menu

- Add the blue envelope and bilingual-card application icon.
- Simplify the menu to clear cache, reload the current message, and quit; keep status in the icon's hover tooltip.

## 0.6 — Mail's remote-content settings

- Let both reading views follow Apple Mail's existing remote-image privacy settings.
- Establish the initial Git baseline for the project.

## Earlier prototypes

Versions 0.2–0.5 introduced actual on-device translation, automatic English → Chinese translation, per-message state, original MIME preservation, one-action controls, and menu bar operation. These predate the initial Git baseline. Historical validation details are kept in the [test archive](outputs/mail-translation-probe/测试记录.md); older UI descriptions do not describe the current version.

中文版本概览：0.9 完整跳过中文原文；0.8 统一 MailTrans 名称并加入可选 Mail 生命周期联动及相关竞争/偏好修复；0.7 新图标与精简菜单；0.6 沿用 Mail 图片隐私设置并建立 Git 基线。
