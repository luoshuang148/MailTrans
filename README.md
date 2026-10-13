# 苹果 Mail 本地翻译

当前版本：**0.7 / build 7**；Git 初始基线为 0.6。通过 MailKit 阅读扩展与苹果 Translation 框架，在 Apple Mail 内将邮件正文翻译为简体中文。

英文正文自动翻译；中文视图提供“显示原文”，原文视图提供“翻译为中文”。保留原始 MIME 与附件字节，尽量保留 HTML 排版、表格、链接和图片。图片加载沿用 Mail 的隐私设置。宿主仅在菜单栏运行，当前翻译引擎为 `apple-local`。

0.7 移除下拉菜单顶部的状态行，菜单从“清空本地缓存”开始；状态保留在菜单栏图标的悬停提示中。应用图标使用蓝色信封与 `A` / `文` 双语卡片，原图与生成提示词见 [图标资源](outputs/mail-translation-probe/assets/)。

## 项目入口

- [交接文档](outputs/mail-translation-probe/交接文档.md)：当前实现、交互要求、安装更新流程和已知限制。
- [使用说明](outputs/mail-translation-probe/说明.md)：现有功能与操作方式。
- [验证记录](outputs/mail-translation-probe/测试记录.md)：历次测试及其覆盖范围。
- [源码](outputs/mail-translation-probe/source/)：Objective-C 宿主、MailKit 扩展、MIME 核心、Swift 翻译引擎及现有测试。
- [人工排版测试邮件](outputs/mail-translation-probe/layout-sample.eml)：由构建脚本生成，不含真实邮件。
- [早期设计](outputs/mail-translation-probe/design/实际邮件接入方案.md)：历史参考；当前行为以交接文档和源码为准。

## 构建与验证

当前只在 Apple Silicon、macOS 26.4、Mail 16.0、Xcode 26.6 / macOS SDK 26.5 上验证。脚本使用 `/Applications/Xcode.app/Contents/Developer`。

在仓库根目录执行：

```sh
python3 outputs/mail-translation-probe/source/build.py
python3 outputs/mail-translation-probe/source/verify_worker.py '/Applications/Mail Translation Probe.app/Contents/MacOS/TranslationWorker'
```

构建会运行 `CoreTests`、`AppTests`、`ExtensionTests`，生成并临时签名 `outputs/mail-translation-probe/Mail Translation Probe.app`，验证签名。worker 检查需要先完成应用安装和英中语言包准备；本机安装副本已通过该检查。2026-10-14 验证时，Documents 构建路径中的相同 worker 返回 `model_missing`，而 `/Applications` 副本通过；具体原因尚未确认，不将构建路径的实际翻译检查记为通过。

构建不会安装或替换 `/Applications` 中的应用。安装更新请遵循交接文档；日常运行使用 `/Applications/Mail Translation Probe.app`。当前为本机开发版，尚未公证或进行跨机器验证。

## 版本控制

仓库保存源码、现有测试、说明、交接与人工测试邮件。`work/`、生成的 `.app` / `.appex`、旧版备份、邮件缓存及本地凭据不提交，继续保留在本机。真实邮件不得作为仓库测试材料。

GitHub：[`luoshuang148/apple-mail-local-translation`](https://github.com/luoshuang148/apple-mail-local-translation)，初始设置为私有仓库。后续开发在此仓库记录变更，保留当前交互要求。
