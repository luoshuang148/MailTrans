# Changelog

User-facing changes are listed below. Version numbers describe application builds; they do not imply a published binary release. See [Git history](https://github.com/luoshuang148/MailTrans/commits/main/) for implementation details.

## v0.11.2 — Automatic reading-view recovery (2026-10-21)

- Recover automatically when Mail restores a message before its MIME data is available and reports no reading view. The extension records a content-free `.last-handled` timestamp only after it has produced or intentionally skipped a reading view; the host checks that marker and the extension process, then asks Mail to reload visible messages until the reading view is rebuilt.
- If the extension process has exited, re-register the enabled extension through `pluginkit` and reload again. Never re-enable an extension the user disabled.
- Keep the recovery bounded: at most six reloads per Mail session. Once a message is handled, no further reloads are requested.
- Leave the existing **重新加载当前邮件** menu action as a manual fallback. No translation-provider, cache-format or privacy changes.
- The app remains ad-hoc signed and unnotarized.

中文：修复 Mail 启动时恢复上次邮件、原始 MIME 尚未就绪，或扩展进程已退出导致正文没有“翻译为中文”控制条的问题。扩展生成或主动跳过阅读视图后写入不含邮件内容的 `.last-handled` 时间戳；宿主检查该标记和扩展进程，必要时请求 Mail 重新加载可见邮件。扩展进程已退出时，通过 `pluginkit` 重新注册已启用的扩展后再刷新；最多重载六次，成功处理任一邮件后停止，不会重新启用用户已停用的扩展。保留菜单中的“重新加载当前邮件”作为手动兜底。翻译引擎、缓存格式和隐私策略未变。

## v0.11.1 — Failure diagnostics (2026-10-21)

- Persist the last translation failure code, message, cache key and timestamp, and restore the error state for the same message when the host relaunches.
- Show the exact failure reason and time in the menu-bar menu and tooltip instead of only a generic warning icon. Add **忽略上次失败提示** to clear the diagnostic without deleting cached mail.
- Clear the persisted failure after a successful retry or cache clearing; keep the cache when dismissing only the warning.
- Log the failure code and a shortened cache key to `os_log` (`local.codex.mailtranslationprobe`, category `translation`) without logging message content.
- No translation-provider, model-download or cloud-fallback changes. The app remains ad-hoc signed and unnotarized.

中文：持久化上次翻译失败的错误代码、说明、缓存键和时间；重启后在邮件仍可用时恢复错误状态。菜单栏和 tooltip 显示具体失败原因与时间，并新增“忽略上次失败提示”，只清提示、不删缓存。成功重试或清空缓存会清除记录；日志只写错误码与短缓存键，不写邮件内容。翻译引擎与云端策略未变，应用仍未公证。

## v0.11.0 — Original-first reading and freeze fixes (2026-10-20)

- Keep an English message in its original view by default. Automatic translation is prepared in the background and cached, but only an explicit **翻译为中文** click activates the Chinese reading view.
- Preserve the cached translation when **显示原文** is chosen, so switching back does not rerun the model.
- Fix cache scans that read every original and translation in full, causing long stalls and high memory use. Recent-message and view checks now use bounded file metadata, with synchronized cache mutations.
- Reuse the parsed MIME tree within a request and clear stale text segments before rendering.
- Avoid full MIME parsing and language detection when Mail reloads an already-active cached translation, reducing the visible reload delay.
- Move automatic cache scans off the main thread and avoid re-activating Mail when it is already frontmost.
- Bound worker shutdown and pipe draining when a grandchild keeps stdout open, preventing a stuck translation task.
- Keep automatic English translation available; there is still no cloud provider or automatic cloud fallback.
- The app remains ad-hoc signed and unnotarized. Mail can still briefly redraw when its reading view reloads.

中文：英文邮件默认继续显示原文，后台准备并缓存中文译文，只有点击“翻译为中文”才切换视图；恢复原文后译文仍保留。修复缓存扫描读取整封邮件导致的卡死、重复解析与视图刷新开销，并限制子进程退出等待。仍无云端翻译，应用仍未公证。

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
