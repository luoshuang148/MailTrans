import Foundation

// Provider boundary: future providers implement this protocol and register an ID.
// The Mail/MIME layer never depends on a specific translation service.
struct TranslationInput: Codable {
    var texts: [String]
    var source: String?
    var target: String?
    var provider: String?
}
struct TranslationOutput: Codable {
    var provider: String
    var translations: [String]?
    var errorCode: String?
    var message: String?
    var source: String?
    var target: String?
}
protocol TranslationProvider {
    var identifier: String { get }
    func translate(_ input: TranslationInput) async throws -> [String]
}
enum ProviderFailure: Error {
    case missingModel(String, String)
    case unsupportedLanguage(String, String)
    case badRequest
    case unavailableProvider
}
