# MailTrans 兼容性调查

2026-10-22；源码参考本分支起点 1bfad9d。没有降低部署版本或修改业务代码。

## 结论

**26.4 是当前 worker API 的实际要求，不能仅改 plist 降级。** 构建环境 SDK 26.5 与部署目标 26.4 是两个概念。MailKit 本身不是 26.4 门槛的原因。

本机 Xcode 26.6 / macOS SDK 26.5 的 Translation.swiftinterface 明确标注：

| API | macOS 可用版本 | 当前使用及影响 |
|---|---|---|
| TranslationSession / LanguageAvailability | 15.0 | Translation 框架核心入口；不足以证明此应用兼容 15 |
| init(installedSource:target:) | 26.0 | 可在无 UI worker 中使用已安装语种 |
| init(installedSource:target:preferredStrategy:) | 26.4 | TranslationWorker.swift 当前直接使用 |
| TranslationSession.Strategy.lowLatency | 26.4 | 当前显式选择的策略 |
| LanguageAvailability(preferredStrategy:) | 26.4 | worker 模型检查同样直接依赖，应一并分支 |
| TranslationSession.cancel | 26.0 | 取消路径也需纳入降级调查 |

SDK 证据位置：`$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/Translation.framework/Modules/Translation.swiftmodule/arm64e-apple-macos.swiftinterface`；在目标 API 前查看 @available。版本结论以实际 SDK 声明为证据，并结合官方文档：

- [TranslationSession](https://developer.apple.com/documentation/translation/translationsession)
- [带策略的初始化](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:preferredstrategy:))
- [已安装语种初始化](https://developer.apple.com/documentation/translation/translationsession/init(installedsource:target:))
- [MailKit](https://developer.apple.com/documentation/mailkit)

## 降级评估

**26.0：可能可行，尚未验证。** 为策略初始化添加 #available(macOS 26.4, *) 分支，旧系统使用不带 preferredStrategy 的构造器。完整审查 TranslationProvider.swift、TranslationWorker.swift、LanguageSetup.swift 的可用性，补齐较旧系统的模型状态/取消/错误路径测试；之后才调整 Sources/build.py 的 plist、ObjC 编译器与 Swift target 版本，并更新 README/compatibility/CI。需 26.0 真机或可信运行环境测试，模型选择、性能、首次安装与 Mail 展示可能不同。

**15：不是简单降部署版本。** 当前无 UI installedSource 初始化最早在 26.0。macOS 15 路线需通过 SwiftUI translationTask 获得 session，重构 worker 和模型准备/生命周期桥接，重新验证后台任务、沙盒、扩展通信与取消行为。当前不建议为推广而承担这项重构。

Apple Silicon 限制既是当前构建目标也是已验证硬件边界；没有 Intel 验证不能宣称支持。Apple 可能收集框架使用与性能指标（不含原译文内容），项目“无遥测”仅指 MailTrans 自身。语言包下载和 Mail 远程图片仍可能联网。
