# MailTrans 名称与 Mail 联动

用户已选择英文名 MailTrans，并要求 Mail 启动时自动启动、Mail 退出时自动退出。用户确认：手动退出 MailTrans 后保持退出，等下次重新启动 Mail 才恢复。

应用包、显示名、菜单退出项、扩展名称及语言包窗口统一使用 MailTrans。保留现有 bundle IDs、缓存位置和 mailtranslationprobe URL scheme，确保扩展身份与已有正文链接兼容。版本为 0.8 / build 8。

通过当前用户 LaunchAgent 启动一个无窗口、无菜单栏图标的 MailTransLifecycle 监听器。监听器使用 NSWorkspace.runningApplications 的 KVO 变化通知（覆盖菜单栏后台应用），不轮询邮件，不获取邮件内容，不需要辅助功能或 AppleScript 权限。监听器在登录会话内待命；MailTrans 主应用、翻译任务和图标只随 Mail 运行。

监听器启动时检查已运行的 Mail；Mail 完全退出后正常请求 MailTrans 退出。关窗口不等同于退出 Mail。以 bundle identifier 识别 Mail，防止同名程序误触发。重复通知或多个 Mail 实例不重复启动主应用；最后一个 Mail 实例退出才关闭主应用。异步启动晚于 Mail 退出时立即关闭迟到的主应用。

跨进程偏好通过统一工厂创建：自身 Bundle ID 使用 standardUserDefaults，其他域使用 suite。用实际应用包/嵌套 helper/CLI 覆盖该系统边界。

每个 Mail 会话由进程 ID 和启动时间标识。手动退出保存本次会话抑制标记，监听器重启也不重新拉起；下次 Mail 启动产生新会话，不受旧标记影响。明确手动打开 MailTrans 可恢复本次使用。退出时停止自身 worker / 语言包任务并清理缓存，阻止迟到结果写回。

新增 enable/disable/status 管理脚本。构建本身不安装 LaunchAgent；本次部署按用户授权安装并启用。后台监听器是实现下一次自动启动所需的辅助进程，停用脚本会移除其 LaunchAgent。

保留原有邮件翻译、单按钮切换、图像隐私策略、菜单结构和图标。用真实的独立测试 app 模拟应用生命周期，不使用真实邮件；最终对 Apple Mail 做正常退出/启动验证，不发送邮件。
