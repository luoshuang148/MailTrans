# Contributing to MailTrans

Thanks for helping make local email translation more useful. Issues and pull requests in **English or Chinese** are welcome. Documentation fixes, synthetic MIME fixtures, accessibility improvements, and compatibility reports are valuable contributions.

## Before you start

- Search [existing issues](https://github.com/luoshuang148/MailTrans/issues) before opening a new one.
- Use the [issue forms](https://github.com/luoshuang148/MailTrans/issues/new/choose) for bugs and feature requests. Discuss large behavior changes before investing in an implementation.
- Read the [current limitations](README.md#current-limitations), [getting started guide](docs/getting-started.md), and [architecture](docs/architecture.md).
- Never attach real emails, mailbox exports, email cache files, addresses, credentials, or screenshots containing private messages. Reproduce with synthetic content and `example.invalid` addresses.
- Report vulnerabilities using [SECURITY.md](SECURITY.md), rather than publishing exploit details in an issue.

## Development setup

Fork the repository, clone your fork, and create a focused branch. The build requires Apple Silicon, macOS 26.4 or later, full Xcode at `/Applications/Xcode.app`, and Python 3. Xcode 26.6 / SDK 26.5 is the verified toolchain.

From the repository root:

```sh
python3 outputs/mail-translation-probe/source/build.py
```

This compiles and runs four native test suites plus the bundled cross-process preferences check, packages the app, and verifies its ad-hoc signature. It does not replace the installed app or enable services. Use the [installation/update guide](docs/getting-started.md) when you need to test in Mail.

After installing and preparing language models, you can separately run:

```sh
python3 outputs/mail-translation-probe/source/verify_worker.py '/Applications/MailTrans.app/Contents/MacOS/TranslationWorker'
```

This executes actual on-device translation; it is separate from the native tests and Mail interface checks. Do not describe model-dependent tests or UI checks as passing unless you ran them.

## Validation by change type

| Change | Expected validation |
| --- | --- |
| Documentation or artwork | Check links, commands, both README languages, and rendered layout. A native rebuild is unnecessary if source and build assets are unaffected. |
| MIME, HTML, caching, language detection | Run a fresh full build and add focused synthetic regressions for the affected behavior. |
| Menu, extension, lifecycle | Run a fresh full build, including app, extension, lifecycle, and cross-process preferences checks. |
| Translation provider or model setup | Run native checks and the installed worker check with the relevant model; report missing models or unavailable environments. |
| Reading-view changes | Check the included `layout-sample.eml` in Mail: translation, original switch, tables, inline image, and link targets. Record your OS/Mail versions. |

Real-world compatibility observations should state the exact environment and what was tested. They do not establish support for every message format or machine.

## Implementation conventions

- Match the surrounding Objective-C, Swift, and Python style. Keep changes focused and avoid unrelated renames.
- Preserve original MIME and attachment bytes. Keep message state isolated and invalidate late translation results after restore, clear, or quit.
- Respect Mail's remote-content settings. Any new cloud provider or outgoing data path needs explicit design discussion and clear user control.
- Preserve bundle IDs and the URL scheme unless a migration has been discussed; existing caches, registrations, and controls depend on them.
- Use synthetic fixtures. Generated `.app` / `.appex` bundles, `work/`, mail caches, and local secrets are excluded from version control.
- Keep [English](README.md) and [Chinese](README.zh-CN.md) user-facing docs consistent. If you can only update one language, call that out in your PR.

## Submit a pull request

Describe the problem, the resulting behavior, and relevant validation. Link an issue if one exists. List material limitations or checks you could not run. A focused PR is easier to review than several unrelated improvements bundled together.

By contributing, you agree that your contribution is available under the project's [MIT license](LICENSE). Please follow our [community guidelines](CODE_OF_CONDUCT.md).

## 中文说明

欢迎中文反馈与 PR。提交前请先检索已有问题，较大的行为变更先讨论。文档改动检查链接和渲染；代码改动运行完整构建，按影响范围补人工测试用例、安装副本 worker 验证或 Mail 界面检查。说明实际运行的检查和未覆盖的环境，不上传真实邮件、缓存或含个人信息的截图。新云端接口、原文保护策略及 bundle ID 迁移应先讨论。
