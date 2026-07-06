import Foundation
import SwiftUI

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
