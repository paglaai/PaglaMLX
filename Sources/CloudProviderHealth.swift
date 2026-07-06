import Foundation
import Observation
import SwiftUI

@MainActor
@Observable final class CloudProviderHealth {
    static let shared = CloudProviderHealth()

    enum Health: Equatable {
        case notConfigured
        case checking
        case ok
        case warning
        case exhausted
        case error(String)

        var dotColor: Color {
            switch self {
            case .notConfigured: return Color(red: 0.922, green: 0.922, blue: 0.945)
            case .checking:      return .gray
            case .ok:            return .green
            case .warning:       return .yellow
            case .exhausted:     return .red
            case .error:         return .red
            }
        }
    }

    struct Status: Equatable {
        var health: Health = .notConfigured
        var detail: String = ""
    }

    var statuses: [String: Status] = [:]
    var isRunning = false

    private struct ProviderDef {
        let id: String
        let testURL: String
        let supportsCredits: Bool
    }

    private let providers: [ProviderDef] = [
        ProviderDef(id: "openrouter",  testURL: "https://openrouter.ai/api/v1/auth/key",            supportsCredits: true),
        ProviderDef(id: "groq",        testURL: "https://api.groq.com/openai/v1/models",            supportsCredits: false),
        ProviderDef(id: "together",    testURL: "https://api.together.xyz/v1/models",               supportsCredits: false),
        ProviderDef(id: "deepseek",    testURL: "https://api.deepseek.com/v1/models",               supportsCredits: false),
        ProviderDef(id: "mistral",     testURL: "https://api.mistral.ai/v1/models",                 supportsCredits: false),
        ProviderDef(id: "perplexity",  testURL: "https://api.perplexity.ai/v1/models",              supportsCredits: false),
        ProviderDef(id: "cohere",      testURL: "https://api.cohere.com/v1/models",                 supportsCredits: false),
        ProviderDef(id: "fireworks",   testURL: "https://api.fireworks.ai/v1/models",               supportsCredits: false),
        ProviderDef(id: "hyperbolic",  testURL: "https://api.hyperbolic.xyz/v1/models",             supportsCredits: false),
        ProviderDef(id: "sambanova",   testURL: "https://api.sambanova.ai/v1/models",               supportsCredits: false),
    ]

    private init() {
        for p in providers {
            statuses[p.id] = Status()
        }
    }

    func checkAll() async {
        isRunning = true
        for p in providers {
            await check(provider: p)
        }
        isRunning = false
    }

    func check(_ id: String) async {
        guard let p = providers.first(where: { $0.id == id }) else { return }
        await check(provider: p)
    }

    private func check(provider: ProviderDef) async {
        let settings = SettingsManager.shared
        let key = keyFor(providerId: provider.id, settings: settings)

        guard !key.isEmpty else {
            statuses[provider.id] = Status(health: .notConfigured, detail: "No key configured")
            return
        }

        statuses[provider.id] = Status(health: .checking, detail: "Checking...")

        guard let url = URL(string: provider.testURL) else {
            statuses[provider.id] = Status(health: .error("Invalid URL"), detail: "")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                statuses[provider.id] = Status(health: .error("Invalid response"), detail: "")
                return
            }

            switch httpResponse.statusCode {
            case 200:
                if provider.supportsCredits, let credits = parseCredits(from: data) {
                    if credits < 0.1 {
                        statuses[provider.id] = Status(health: .exhausted, detail: String(format: "$%.2f credits", credits))
                    } else if credits < 1.0 {
                        statuses[provider.id] = Status(health: .warning, detail: String(format: "$%.2f credits", credits))
                    } else {
                        statuses[provider.id] = Status(health: .ok, detail: String(format: "$%.2f credits", credits))
                    }
                } else {
                    statuses[provider.id] = Status(health: .ok, detail: "Connected")
                }

            case 401, 403:
                statuses[provider.id] = Status(health: .exhausted, detail: "Invalid key (HTTP \(httpResponse.statusCode))")

            case 429:
                statuses[provider.id] = Status(health: .warning, detail: "Rate limited")

            default:
                statuses[provider.id] = Status(health: .warning, detail: "HTTP \(httpResponse.statusCode)")
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet {
                statuses[provider.id] = Status(health: .error("No internet"), detail: "")
            } else {
                statuses[provider.id] = Status(health: .error(error.localizedDescription), detail: "")
            }
        }
    }

    private func parseCredits(from data: Data) -> Double? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let credits = dataObj["credits"] as? Double else {
            return nil
        }
        return credits
    }

    private func keyFor(providerId: String, settings: SettingsManager) -> String {
        switch providerId {
        case "openrouter": return settings.freeRouterKey
        case "groq":       return settings.groqKey
        case "together":   return settings.togetherKey
        case "deepseek":   return settings.deepseekKey
        case "mistral":    return settings.mistralKey
        case "perplexity": return settings.perplexityKey
        case "cohere":     return settings.cohereKey
        case "fireworks":  return settings.fireworksKey
        case "hyperbolic": return settings.hyperbolicKey
        case "sambanova":  return settings.sambanovaKey
        default:           return ""
        }
    }
}
