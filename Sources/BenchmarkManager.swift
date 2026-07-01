import Foundation
import Observation

struct BenchmarkResult: Identifiable {
    let id = UUID()
    let modelName: String
    let date: Date
    let tokensPerSecond: Double
    let totalTokens: Int
    let latencyMs: Double
    let promptTokens: Int
    let modelSizeGB: Double
    let contextLength: Int
}

@MainActor
@Observable final class BenchmarkManager {
    static let shared = BenchmarkManager()

    var isRunning = false
    var results: [BenchmarkResult] = []
    var currentProgress = ""
    var errorMessage: String?

    private init() {}

    func runBenchmark(model: MLXModel, port: Int, apiKey: String) {
        isRunning = true
        currentProgress = "Warming up..."
        errorMessage = nil

        let prompt = "Write a short paragraph about the history of artificial intelligence. Keep it concise."
        let promptTokens = prompt.split(separator: " ").count

        Task {
            let startTime = Date()

            let url = URL(string: "http://127.0.0.1:\(SettingsManager.shared.port)/v1/chat/completions")!
            var request = URLRequest(url: url, timeoutInterval: 120)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            let body: [String: Any] = [
                "model": model.name,
                "messages": [["role": "user", "content": prompt]],
                "max_tokens": 256,
                "stream": false
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                currentProgress = "Running inference..."
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    errorMessage = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    currentProgress = ""
                    isRunning = false
                    return
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let usage = json["usage"] as? [String: Any] else {
                    errorMessage = "Invalid response format"
                    currentProgress = ""
                    isRunning = false
                    return
                }

                let completionTokens = usage["completion_tokens"] as? Int ?? 0
                let totalTime = Date().timeIntervalSince(startTime)
                let tokPerSec = totalTime > 0 ? Double(completionTokens) / totalTime : 0

                let result = BenchmarkResult(
                    modelName: model.name,
                    date: Date(),
                    tokensPerSecond: tokPerSec,
                    totalTokens: completionTokens,
                    latencyMs: totalTime * 1000,
                    promptTokens: promptTokens,
                    modelSizeGB: model.sizeGB,
                    contextLength: model.contextLength
                )
                results.insert(result, at: 0)
                if results.count > 20 { results.removeLast() }
                currentProgress = ""
            } catch {
                errorMessage = error.localizedDescription
                currentProgress = ""
            }
            isRunning = false
        }
    }
}
