import Foundation
import SwiftUI
import Observation

struct RequestRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let modelName: String
    let tokensPerSecond: Double
    let latencyMs: Double
    let error: Bool
}

@MainActor
@Observable final class ActivityTracker {
    static let shared = ActivityTracker()

    private(set) var records: [RequestRecord] = []
    private let maxRecords = 1000

    var totalRequests: Int { records.count }
    var totalErrors: Int { records.filter(\.error).count }

    var averageTokensPerSecond: Double {
        let completed = records.filter { !$0.error && $0.tokensPerSecond > 0 }
        guard !completed.isEmpty else { return 0 }
        return completed.map(\.tokensPerSecond).reduce(0, +) / Double(completed.count)
    }

    var averageLatencyMs: Double {
        let completed = records.filter { !$0.error }
        guard !completed.isEmpty else { return 0 }
        return completed.map(\.latencyMs).reduce(0, +) / Double(completed.count)
    }

    var recentRequests: [RequestRecord] {
        Array(records.suffix(50))
    }

    var requestsLastMinute: Int {
        let cutoff = Date().addingTimeInterval(-60)
        return records.filter { $0.timestamp > cutoff }.count
    }

    var errorsLastMinute: Int {
        let cutoff = Date().addingTimeInterval(-60)
        return records.filter { $0.timestamp > cutoff && $0.error }.count
    }

    func record(modelName: String, tokensPerSecond: Double, latencyMs: Double, error: Bool) {
        let record = RequestRecord(
            timestamp: Date(),
            modelName: modelName,
            tokensPerSecond: tokensPerSecond,
            latencyMs: latencyMs,
            error: error
        )
        records.append(record)
        if records.count > maxRecords {
            records.removeFirst(records.count - maxRecords)
        }
    }

    func clear() {
        records.removeAll()
    }

    func recordCount(for modelName: String) -> Int {
        records.filter { $0.modelName == modelName }.count
    }
}
