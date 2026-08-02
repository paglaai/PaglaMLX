import Foundation
import SwiftUI

// MARK: - Event Types

enum EventStatus: String, Codable, CaseIterable {
    case success
    case failed
    case pending
    case running
}

enum EventType: String, Codable, CaseIterable {
    case request
    case modelLoad
    case modelUnload
    case error
    case system

    var rawValueForJSON: String {
        switch self {
        case .request: return "request"
        case .modelLoad: return "model_load"
        case .modelUnload: return "model_unload"
        case .error: return "error"
        case .system: return "system"
        }
    }
}

struct GatewayEvent: Codable {
    let timestamp: String
    let eventType: EventType
    let model: String
    let requestID: String
    let status: EventStatus
    let durationMs: Int
    let message: String?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case eventType = "event_type"
        case model
        case requestID = "request_id"
        case status
        case durationMs = "duration_ms"
        case message
    }
}

class EventRecorder {
    private let eventFileURL: URL
    private let queue = DispatchQueue(label: "com.paglaai.eventrecorder", qos: .utility)
    private let isoFormatter = ISO8601DateFormatter()

    init(customPath: URL? = nil) {
        if let custom = customPath {
            self.eventFileURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let paglaDir = appSupport.appendingPathComponent("PaglaMLX", isDirectory: true)
            self.eventFileURL = paglaDir.appendingPathComponent("events.jsonl")
        }

        let dir = eventFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func record(
        eventType: EventType,
        model: String,
        requestID: String,
        status: EventStatus,
        durationMs: Int,
        message: String? = nil
    ) {
        let event = GatewayEvent(
            timestamp: isoFormatter.string(from: Date()),
            eventType: eventType,
            model: model,
            requestID: requestID,
            status: status,
            durationMs: durationMs,
            message: message
        )
        append(event)
    }

    func recordModelLifecycle(action: LifecycleAction, model: String, durationMs: Int) {
        let eventType: EventType = action == .load ? .modelLoad : .modelUnload
        let status: EventStatus = .success
        let event = GatewayEvent(
            timestamp: isoFormatter.string(from: Date()),
            eventType: eventType,
            model: model,
            requestID: "lifecycle_\(model)_\(action.rawValue)",
            status: status,
            durationMs: durationMs,
            message: nil
        )
        append(event)
    }

    enum LifecycleAction: String {
        case load
        case unload
    }

    /// Blocks the calling thread until all previously enqueued writes have finished.
    /// Use in tests to ensure the file is complete before reading.
    func flush() {
        queue.sync {}
    }

    private func append(_ event: GatewayEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(event)
                var line = String(data: data, encoding: .utf8) ?? ""
                line += "\n"
                if let fileHandle = try? FileHandle(forWritingTo: self.eventFileURL) {
                    fileHandle.seekToEndOfFile()
                    if let lineData = line.data(using: .utf8) {
                        fileHandle.write(lineData)
                    }
                    fileHandle.closeFile()
                } else {
                    try line.data(using: .utf8)?.write(to: self.eventFileURL)
                }
            } catch {
                print("[EventRecorder] Failed to write event: \(error)")
            }
        }
    }
}

// MARK: - MLXModel
struct MLXModel: Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let sizeGB: Double
    let contextLength: Int
    let modelType: String
    
    var sizeFormatted: String {
        return sizeGB > 0 ? String(format: "%.1f GB", sizeGB) : "Unknown Size"
    }
    
    var typeIcon: String {
        return modelType == "VLM" ? "eye" : "cpu"
    }
}

// MARK: - LogEntry
struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let level: Level
    
    enum Level: CaseIterable {
        case info
        case stderr
        case error
        case success
        case warning
        case detail

        var label: String {
            switch self {
            case .info:    return "INFO"
            case .stderr:  return "STDERR"
            case .error:   return "ERROR"
            case .success: return "OK"
            case .warning: return "WARN"
            case .detail:  return "DETAIL"
            }
        }

        var color: Color {
            switch self {
            case .info:    return Color(NSColor.textColor)
            case .stderr:  return Color.orange
            case .error:   return Color.red
            case .success: return Color.green
            case .warning: return Color.orange
            case .detail:  return Color.secondary
            }
        }
    }
    
    var color: Color {
        switch level {
        case .info:    return Color(NSColor.textColor)
        case .stderr:  return Color.orange
        case .error:   return Color.red
        case .success: return Color.green
        case .warning: return Color.orange
        case .detail:  return Color.secondary
        }
    }
    
    init(_ text: String, level: Level = .info) {
        self.text = text
        self.level = level
    }
}
