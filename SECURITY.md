# Security policy

MailTrans handles email body content and temporary original-message copies. Privacy and safe MIME processing are central to the project.

## Supported versions

Security fixes are developed for the latest source on `main` (currently the 0.9 development line). Older builds have no separate maintenance guarantee. This is an experimental project with best-effort review, not a promised response-time or support service.

## Report a vulnerability

Use GitHub's [private vulnerability reporting](https://github.com/luoshuang148/apple-mail-local-translation/security/advisories/new) for suspected vulnerabilities. If that entry point is unavailable, open an issue requesting a private reporting channel **without publishing vulnerability details**.

Include the affected version or commit, macOS/Mail versions, impact, and a minimal synthetic reproduction. Do not submit real email, cache contents, personal addresses, access tokens, or an unsanitized mailbox export.

Ordinary installation failures, model errors, and translation-quality problems belong in the [bug report form](https://github.com/luoshuang148/apple-mail-local-translation/issues/new/choose).

## Privacy boundaries

- The current provider uses Apple's on-device Translation framework. There is no cloud translation provider or telemetry.
- Initial language-model setup may download models. Remote images follow Apple Mail's existing privacy settings.
- Cached originals can include attachments. Review the [cache lifecycle](docs/getting-started.md#cache-and-privacy) before testing with sensitive data.
- The app is ad-hoc signed and not notarized. Signature verification checks bundle integrity, not publisher identity.
- Signed/encrypted and unsafe-to-parse messages are skipped. A translation is reading content, not a modification of the stored original.

## 中文说明

疑似漏洞请使用上方 GitHub 私密漏洞报告入口。入口不可用时，可开 Issue 请求私下反馈渠道，但不要公开漏洞细节。提供受影响版本、系统和 Mail 版本、影响及人工复现材料，不提供真实邮件、缓存或凭据。普通安装、语言包和翻译质量问题使用 Bug 表单。项目处于实验阶段，仅对最新主分支尽力维护，没有承诺响应时限。
