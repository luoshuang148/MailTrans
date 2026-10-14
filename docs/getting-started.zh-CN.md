# MailTrans 安装与使用

[首页](../README.zh-CN.md) · [English](getting-started.md)

0.9 是需要从源码构建的实验版本。目前没有经过正式签名、公证的下载包，跨机器安装尚未验证。

## 环境要求

| 项目 | 当前要求 / 已验证环境 |
| --- | --- |
| 硬件 | Apple Silicon；Swift worker 以 `arm64` 为目标构建 |
| 系统 | 最低 macOS 26.4；已验证 macOS 26.4 |
| 邮件客户端 | Apple Mail；已验证 Mail 16.0 |
| 开发工具 | 完整 Xcode 位于 `/Applications/Xcode.app`；已验证 Xcode 26.6 / macOS SDK 26.5 |
| 构建工具 | Python 3，以及 macOS 自带的 `sips`、`iconutil`、`codesign` |
| 语言模型 | 苹果提供的源语言 → 简体中文模型；首次可能需要下载 |

仅安装 Command Line Tools 不属于已说明的构建环境。满足最低版本要求不代表该系统或工具链已经经过验证。

## 从源码构建

```sh
git clone https://github.com/luoshuang148/MailTrans.git
cd MailTrans
python3 outputs/mail-translation-probe/source/build.py
```

脚本运行 `CoreTests`、`AppTests`、`ExtensionTests`、`LifecycleTests` 及真实跨进程偏好共享检查，编译宿主、扩展、翻译 worker 与辅助程序，并临时签名及验证应用包。

产物为 `outputs/mail-translation-probe/MailTrans.app`，中间文件位于被 Git 忽略的 `work/mail-real/`。构建不安装应用、不启用扩展、不下载模型，也不安装 LaunchAgent。构建通过不等于实际翻译和 Mail 界面验证通过。

## 安装与启用

已有安装时，请先阅读[更新](#更新)。

1. 退出 Mail。在 Finder 中将生成的 `MailTrans.app` 复制到 `/Applications`，保留一个正式安装副本，日常运行使用该副本。
2. 在终端检查安装包签名：

   ```sh
   codesign --verify --deep --strict '/Applications/MailTrans.app'
   ```

   此命令验证应用包完整性；临时签名不提供 Developer ID 身份或公证。失败时参见[常见问题](#常见问题)。
3. 先打开 Mail，再打开 `/Applications/MailTrans.app`；Mail 未运行时宿主会立即退出。在**邮件 → 设置 → 扩展**中勾选 **MailTrans**。找不到扩展时，注册安装副本并重启 Mail：

   ```sh
   pluginkit -a '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
   ```

4. 打开随仓库提供的人工测试邮件：

   ```sh
   open -a Mail outputs/mail-translation-probe/layout-sample.eml
   ```

5. 如果缺少英中模型，点击**翻译为中文**，按苹果的原生提示准备语言包。自动翻译不会静默下载模型，取消则保留原文。
6. 语言包准备后重新加载邮件，检查自动翻译、**显示原文**、**翻译为中文**，以及两种视图中的表格、内嵌图片与链接。具体译文可能随苹果模型变化。

MailKit 权限提示可能提及读取所有邮件、修改发出的邮件。本工具实现阅读时的译文显示，不发送、转发邮件或向邮箱写回修改，不需要辅助功能、AppleScript 自动化或全磁盘访问权限。

应用尚未公证。若 macOS 阻止启动或无法启用扩展，请提供准确报错和系统版本，不要关闭系统级安全保护。其他机器的安装属于待验证范围。

## 日常使用

- **英文邮件**：打开后自动后台翻译；首次需等待，已有缓存则更快显示。
- **中文译文**：点击**显示原文**恢复原始内容，同时保留独立控制条。
- **原文视图**：点击**翻译为中文**切回译文。选择原文后，有效缓存期间不会被尚未完成的自动任务覆盖。
- **中文原文**：没有控制条，不写翻译缓存。识别依据正文，中文开头的回复也保守保留原样。
- **其他源语言**：手动点击**翻译为中文**，能否翻译取决于苹果支持的语言组合。
- **菜单栏**：提供**清空本地缓存**、**重新加载当前邮件**和**退出 MailTrans**；悬停图标可看状态。

## 可选自动联动

安装应用后，在仓库根目录执行：

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py enable
python3 outputs/mail-translation-probe/source/manage_lifecycle.py status
```

这会在 `~/Library/LaunchAgents/local.codex.mailtranslationprobe.lifecycle.plist` 安装当前用户的 LaunchAgent。无界面的 `MailTransLifecycle` 监听器观察应用进程变化，等待 Mail 启动；菜单栏主程序随 Mail 启动和退出。关闭 Mail 窗口不等于退出 Mail。

手动退出 MailTrans 后，本次 Mail 会话保持退出，即使监听器重启也不会重新拉起；下次重新启动 Mail 恢复自动联动，也可手动打开 MailTrans 立即恢复。

停用自动联动：

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py disable
```

此操作移除监听器服务；如需完全停止翻译，还需在 Mail 设置中取消勾选扩展。

## 更新

1. 已启用自动联动时，先运行上面的 `disable` 命令。
2. 在 Mail 设置中取消勾选 MailTrans，退出 Mail，并从菜单退出 MailTrans，等待相关进程结束。
3. 将旧应用备份到 `/Applications` 以外，更新源码，并用 `build.py` 重新构建。
4. 替换前移除旧安装副本及构建副本的扩展注册：

   ```sh
   pluginkit -r '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
   pluginkit -r "$PWD/outputs/mail-translation-probe/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex"
   ```

   从未注册的副本可能没有可移除的记录。
5. 将新构建替换到 `/Applications/MailTrans.app`，按[安装与启用](#安装与启用)中的命令验证签名并注册安装副本。
6. 先打开 Mail，再打开 `/Applications/MailTrans.app` 并启用扩展，按需恢复自动联动。仍加载旧扩展时重启 Mail，并重新检查人工邮件。

不要在扩展或辅助进程仍运行时覆盖应用包。

## 缓存与隐私

缓存目录：

```text
~/Library/Containers/local.codex.mailtranslationprobe.extension/Data/Library/Caches/MailTranslation
```

缓存含临时原文副本（可能包括附件）、译文以及原文/中文显示状态，不是邮箱，也不是苹果语言包存储。本工具不将缓存上传到翻译服务。

最多 20 封，30 分钟未使用则失效；运行时每分钟清理，正常退出清空，强制结束后可能留有文件，在下次运行时清理。目录权限 `0700`、文件权限 `0600`，检查键、哈希及符号链接。

通过**清空本地缓存**立即清除；Mail 刷新后可能重新缓存当前原文。Mail 自身的数据和备份另行管理，远程图片继续沿用 Mail 已有的隐私及内容加载设置。

## 卸载

1. 从菜单清空本地缓存。
2. 删除应用前执行 `manage_lifecycle.py disable`，完成前保留源码目录。
3. 在 Mail 设置中停用扩展，退出 Mail 与 MailTrans。
4. 用上面的 `pluginkit -r` 命令移除安装副本的扩展注册，将 `/Applications/MailTrans.app` 移至废纸篓。
5. 强制结束后若有残留，仅在 Mail 与 MailTrans 停止时删除上述 `MailTranslation` 缓存目录。

此过程不删除邮箱邮件或苹果语言模型。

## 常见问题

| 情况 | 检查方式 |
| --- | --- |
| 扩展列表找不到 MailTrans | 安装 `/Applications` 副本并注册其 `.appex`，重启 Mail 后再打开 MailTrans，检查最低系统版本。 |
| 英文仍未翻译 | 启用扩展并运行宿主，手动准备语言模型后重新加载邮件；检查是否签名、加密或超过首页限制。 |
| `model_missing` | 按原生提示准备对应语言组合后重试。相同 worker 曾在同步 Documents 构建路径与 `/Applications` 安装路径得到不同结果，原因尚未确认。 |
| 签名报错提及 FinderInfo / resource fork | 在 iCloud 等同步目录外重新构建、复制新副本并检查签名。构建仅清理生成包中不兼容的元数据，同步目录可能重新附加这些属性。 |
| macOS 阻止启动 | 当前是临时签名开发版，未经过分发公证；反馈准确警告与环境，供兼容性验证。 |
| 中文原文没有按钮 | 正常行为，中文正文直接交给 Mail，中文开头且带英文引用或签名的回复也保留原样。 |
| 远程图片不可见 | 检查 Mail 的远程内容设置和图片来源，工具不覆盖这些设置。 |
| 退出 Mail 后仍有监听器 | 正常行为，无界面监听器等待下次 Mail 启动，可用 `disable` 移除。 |
| 手动退出后工具不自动恢复 | 当前 Mail 会话内保持退出；手动打开 MailTrans 或退出并重新打开 Mail。 |

准备语言包后，可单独验证安装副本的真实翻译：

```sh
python3 outputs/mail-translation-probe/source/verify_worker.py '/Applications/MailTrans.app/Contents/MacOS/TranslationWorker'
```

此命令检查实际本地翻译、顺序、中文保留及错误路径，不验证 Mail 界面排版。仍有问题时通过[反馈表单](https://github.com/luoshuang148/MailTrans/issues/new/choose)，附人工复现材料和清理后的输出。
