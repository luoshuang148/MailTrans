import AppKit
import SwiftUI
import Translation

struct SetupView: View {
    let source: Locale.Language
    let target: Locale.Language
    @State private var status = "正在准备本地翻译语言包…"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("准备苹果本地翻译").font(.title2).bold()
            Text("只下载语言模型。邮件正文不会上传到翻译服务器。")
            Text(status).foregroundStyle(.secondary)
            Button("取消并保留原文") { exit(1) }
        }
        .padding(28).frame(width: 460, height: 210)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
        .onDisappear { exit(1) }
        .translationTask(source: source, target: target) { session in
            do {
                try await session.prepareTranslation()
                await MainActor.run { status = "语言包已准备好。正在返回邮件翻译…" }
                FileHandle.standardOutput.write(Data("MAIL_TRANSLATION_MODELS_READY\n".utf8))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { exit(0) }
            } catch {
                await MainActor.run { status = "语言包准备未完成。可关闭此窗口，稍后重试。" }
            }
        }
    }
}
@main struct LanguageSetup: App {
    init() { NSApplication.shared.setActivationPolicy(.regular) }
    var body: some Scene {
        WindowGroup("下载本地翻译语言包") {
            SetupView(source: Locale.Language(identifier: CommandLine.arguments.dropFirst().first ?? "en"), target: Locale.Language(identifier: "zh-Hans"))
        }.windowResizability(.contentSize)
    }
}
