import Foundation
import Translation
import NaturalLanguage

struct AppleLocalProvider: TranslationProvider {
    let identifier = "apple-local"
    func language(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }
    func translate(_ input: TranslationInput) async throws -> [String] {
        let targetID = input.target ?? "zh-Hans"
        guard input.texts.count <= 1024, input.texts.reduce(0, { $0 + $1.count }) <= 200000,
              input.texts.allSatisfy({ $0.count <= 10000 }) else { throw ProviderFailure.badRequest }
        let major = input.source ?? language(String(input.texts.joined(separator: "\n").prefix(20000))) ?? "en"
        let target = Locale.Language(identifier: targetID)
        var groups: [String: [Int]] = [:]
        var output = input.texts
        for (index, text) in input.texts.enumerated() {
            let detected = language(text)
            if detected?.hasPrefix("zh") == true && targetID.hasPrefix("zh") { continue }
            let source = input.source ?? (text.count >= 50 ? detected : nil) ?? major
            if source.hasPrefix("zh") && targetID.hasPrefix("zh") { continue }
            groups[source, default: []].append(index)
        }
        let availability = LanguageAvailability(preferredStrategy: .lowLatency)
        // Check the full set first: do not partially translate a message.
        for source in groups.keys.sorted() {
            switch await availability.status(from: Locale.Language(identifier: source), to: target) {
            case .installed: break
            case .supported: throw ProviderFailure.missingModel(source, targetID)
            case .unsupported: throw ProviderFailure.unsupportedLanguage(source, targetID)
            @unknown default: throw ProviderFailure.unsupportedLanguage(source, targetID)
            }
        }
        for source in groups.keys.sorted() {
            let session = TranslationSession(installedSource: Locale.Language(identifier: source), target: target, preferredStrategy: .lowLatency)
            let indices = groups[source]!
            // Bounded batches reduce memory and keep stable positional identifiers.
            for start in stride(from: 0, to: indices.count, by: 32) {
                let chunk = Array(indices[start..<min(start + 32, indices.count)])
                let requests = chunk.map { TranslationSession.Request(sourceText: input.texts[$0], clientIdentifier: String($0)) }
                let responses = try await session.translations(from: requests)
                guard responses.count == chunk.count else { throw ProviderFailure.badRequest }
                var seen = Set<Int>()
                for response in responses {
                    guard let id = response.clientIdentifier, let index = Int(id), chunk.contains(index),
                          seen.insert(index).inserted else { throw ProviderFailure.badRequest }
                    output[index] = response.targetText
                }
            }
        }
        return output
    }
}

@main struct TranslationWorker {
    static func emit(_ result: TranslationOutput, code: Int32) -> Never {
        if let data = try? JSONEncoder().encode(result) {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data([10]))
        }
        exit(code)
    }
    static func main() async {
        do {
            let bytes = FileHandle.standardInput.readDataToEndOfFile()
            guard bytes.count <= 2_000_000 else { throw ProviderFailure.badRequest }
            let input = try JSONDecoder().decode(TranslationInput.self, from: bytes)
            let providers: [String: any TranslationProvider] = ["apple-local": AppleLocalProvider()]
            guard let provider = providers[input.provider ?? "apple-local"] else { throw ProviderFailure.unavailableProvider }
            let text = try await provider.translate(input)
            emit(TranslationOutput(provider: provider.identifier, translations: text), code: 0)
        } catch ProviderFailure.missingModel(let source, let target) {
            emit(TranslationOutput(provider: "apple-local", errorCode: "model_missing", message: "需要先下载本地翻译语言包。", source: source, target: target), code: 2)
        } catch ProviderFailure.unsupportedLanguage(let source, let target) {
            emit(TranslationOutput(provider: "apple-local", errorCode: "unsupported_language", message: "苹果本地翻译暂不支持此语言组合。", source: source, target: target), code: 3)
        } catch ProviderFailure.unavailableProvider {
            emit(TranslationOutput(provider: "", errorCode: "provider_unavailable", message: "此翻译引擎尚未接入。"), code: 4)
        } catch {
            // Never echo source text or internal framework descriptions to logs.
            emit(TranslationOutput(provider: "apple-local", errorCode: "translation_failed", message: "本地翻译未完成，原文已保留。"), code: 1)
        }
    }
}
