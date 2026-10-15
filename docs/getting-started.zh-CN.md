# MailTrans 安装与使用

[首页](../README.zh-CN.md) · [English](getting-started.md)

0.10 为开发预发布版。[Release](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0) 提供应用 ZIP 与 SHA-256 文件，应用为临时签名，**没有 Developer ID 分发签名或公证**，下载后的系统接受情况及独立 Mac 安装尚待验证。系统阻止时可从源码构建，不关闭系统级安全保护。

## 环境要求

| 项目 | 当前要求 / 已验证环境 |
| --- | --- |
| 硬件 | Apple Silicon；Swift worker 以 `arm64` 为目标构建 |
| 系统 | 最低 macOS 26.4；已验证 macOS 26.4 |
| 邮件客户端 | Apple Mail；已验证 Mail 16.0 |
| 开发工具（仅源码构建） | 完整 Xcode 位于 `/Applications/Xcode.app`；已验证 Xcode 26.6 / macOS SDK 26.5 |
| 构建工具（仅源码构建） | Python 3，以及 macOS 自带的 `sips`、`iconutil`、`codesign` |
| 语言模型 | 苹果提供的源语言 → 简体中文模型；首次可能需要下载 |

运行应用本身不需要 Python 或 Xcode。源码构建使用 `DEVELOPER_DIR` 或 `xcode-select` 选中的工具链，也支持 `--developer-dir PATH`。仅安装 Command Line Tools 不属于已说明的完整构建环境。满足最低版本要求不代表该系统或工具链已经经过验证。

## 从源码构建

```sh
git clone https://github.com/luoshuang148/MailTrans.git
cd MailTrans
python3 outputs/mail-translation-probe/source/build.py
```

脚本运行七组原生测试（核心、宿主、扩展、生命周期、子进程、应用管理、设置）、真实跨进程偏好检查及模型状态协议检查，编译宿主、扩展、翻译 worker 与辅助程序，并临时签名及验证应用包。

产物为 `outputs/mail-translation-probe/MailTrans.app`，中间文件位于被 Git 忽略的 `work/mail-real/`。构建不安装应用、不启用扩展、不下载模型，也不安装 LaunchAgent。构建通过不等于实际翻译和 Mail 界面验证通过。

## 安装与启用

已有安装时，请先阅读[更新](#更新)。

1. 从[开发版 Release](https://github.com/luoshuang148/MailTrans/releases/tag/v0.10.0) 下载应用 ZIP 与配套 `.sha256` 文件。在下载目录执行 `shasum -a 256 -c MailTrans-0.10.0-macos-arm64-development.zip.sha256` 核对完整性，再用 macOS 归档实用工具解压。源码用户可使用自己的构建产物。
2. 将 `MailTrans.app` 移入 `/Applications`，打开该副本。不要从下载目录或临时转移路径启用自动联动。临时签名只验证包完整性，不提供开发者身份；macOS 阻止时，请反馈准确提示或从源码构建，不关闭系统级保护。
3. 首次显示 **MailTrans 设置**，Mail 尚未运行也可使用。点击**打开“邮件”**，在**邮件 → 设置 → 扩展**中勾选 **MailTrans**。设置页的注册检查不能证明已勾选，仍需在 Mail 中确认。
4. 查看英中语言包状态，点击**准备英中语言包**打开苹果原生准备窗口。首次可能需要下载；取消则保留原文。
5. 按需勾选**随“邮件”自动启动和退出**，无需 Python。点击**完成设置**。以后可从菜单栏的**设置与帮助…**再次打开。
6. 点击**打开示例邮件**，检查自动翻译、**显示原文**、**翻译为中文**以及两种视图中的表格、内嵌图片与链接。具体译文可能随苹果模型变化。

找不到已安装扩展时，可用以下高级检查，再重启 Mail 并确认扩展开关：

```sh
pluginkit -a '/Applications/MailTrans.app/Contents/PlugIns/MailTranslationProbe.appex'
codesign --verify --deep --strict '/Applications/MailTrans.app'
```

临时签名验证不能代替公证或跨机器验证。MailKit 的权限提示可能提及读取所有邮件、修改发出邮件；本工具仅实现阅读时的译文显示，不发送、转发或向邮箱写回修改，不需要辅助功能、AppleScript 自动化或全磁盘访问权限。

## 日常使用

- **英文邮件**：打开后自动后台翻译；首次需等待，已有缓存则更快显示。
- **中文译文**：点击**显示原文**恢复原始内容，同时保留独立控制条。
- **原文视图**：点击**翻译为中文**切回译文。选择原文后，有效缓存期间不会被尚未完成的自动任务覆盖。
- **中文原文**：没有控制条，不写翻译缓存。识别依据正文，中文开头的回复也保守保留原样。
- **其他源语言**：手动点击**翻译为中文**，能否翻译取决于苹果支持的语言组合。
- **自动翻译**：菜单中的**自动翻译英文邮件**默认开启，关闭后记住选择；暂停期间仍可手动翻译及切换缓存译文。
- **取消与重试**：**取消当前翻译**停止当前任务；**重试上次失败的邮件**只重试对应的缓存邮件，缓存过期会提示重新打开。翻译 worker 在 120 秒后超时，保留原文。
- **状态与菜单**：错误会显示提醒图标与悬停说明，暂停会显示暂停图标。还可清空缓存、重新加载当前邮件、打开**设置与帮助…**或退出。

## 可选自动联动

可直接在**设置与帮助…**中启用或关闭自动联动。开发者仍可使用原 CLI；安装应用后，在仓库根目录执行：

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py enable
python3 outputs/mail-translation-probe/source/manage_lifecycle.py status
```

这会在 `~/Library/LaunchAgents/local.codex.mailtranslationprobe.lifecycle.plist` 安装当前用户的 LaunchAgent。无界面的 `MailTransLifecycle` 监听器观察应用进程变化，等待 Mail 启动；菜单栏主程序随 Mail 启动和退出。关闭 Mail 窗口不等于退出 Mail。Mail 关闭时手动打开 MailTrans，可保留设置窗口。

手动退出 MailTrans 后，本次 Mail 会话保持退出，即使监听器重启也不会重新拉起；下次重新启动 Mail 恢复自动联动，也可手动打开 MailTrans 立即恢复。

停用自动联动：

```sh
python3 outputs/mail-translation-probe/source/manage_lifecycle.py disable
```

此操作移除监听器服务；如需完全停止翻译，还需在 Mail 设置中取消勾选扩展。

## 更新

1. 已启用自动联动时，先在设置中关闭，或运行上面的开发者 `disable` 命令。
2. 在 Mail 设置中取消勾选 MailTrans，退出 Mail，并从菜单退出 MailTrans，等待相关进程结束。
3. 将旧应用备份到 `/Applications` 以外，下载、校验并解压新版 ZIP；也可更新源码后用 `build.py` 重新构建。
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

图形界面方式：先退出 Mail，若 MailTrans 跟随退出则手动重新打开。进入**设置与帮助… → 卸载 MailTrans…**，核对具体应用路径后确认。程序会先停用监听器、注销扩展，再仅将该应用移入废纸篓，并清空翻译缓存。取消不做操作；停用或注销失败时保留应用并显示错误。

手动卸载方式：

1. 从菜单清空本地缓存。
2. 删除应用前在设置中停用自动联动，或执行 `manage_lifecycle.py disable`；使用 CLI 时完成前保留源码目录。
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
