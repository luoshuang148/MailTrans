# Changelog

User-facing changes are listed below. Version numbers describe application builds; they do not imply a published binary release. See [Git history](https://github.com/luoshuang148/MailTrans/commits/main/) for implementation details.

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
