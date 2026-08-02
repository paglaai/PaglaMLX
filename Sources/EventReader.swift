import Foundation

/// JSONLEventReader: Parse and query append-only event stream
/// Reads ~/.paglamlx/events.jsonl with filtering, streaming, and export capabilities

class EventReader {
    private let eventFileURL: URL
    
    init(customPath: URL? = nil) {
        if let custom = customPath {
            self.eventFileURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let paglaDir = appSupport.appendingPathComponent("PaglaMLX", isDirectory: true)
            self.eventFileURL = paglaDir.appendingPathComponent("events.jsonl")
        }
    }
    
    /// Read all events from the file
    func readAll() throws -> [GatewayEvent] {
        guard FileManager.default.fileExists(atPath: eventFileURL.path) else {
            return []
        }
        
        let content = try String(contentsOf: eventFileURL, encoding: .utf8)
        return parseLines(content)
    }
    
    /// Read events with optional filters
    func query(
        model: String? = nil,
        status: EventStatus? = nil,
        eventType: EventType? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        limit: Int? = nil
    ) throws -> [GatewayEvent] {
        var events = try readAll()
        let formatter = ISO8601DateFormatter()
        
        // Filter by model
        if let model = model {
            events = events.filter { $0.model == model }
        }
        
        // Filter by status
        if let status = status {
            events = events.filter { $0.status == status }
        }
        
        // Filter by event type
        if let eventType = eventType {
            events = events.filter { $0.eventType == eventType }
        }
        
        // Filter by time range
        if let startTime = startTime {
            let startStr = formatter.string(from: startTime)
            events = events.filter { $0.timestamp >= startStr }
        }
        
        if let endTime = endTime {
            let endStr = formatter.string(from: endTime)
            events = events.filter { $0.timestamp <= endStr }
        }
        
        // Apply limit (keeping most recent)
        if let limit = limit, events.count > limit {
            events = Array(events.suffix(limit))
        }
        
        return events
    }
    
    /// Stream events line-by-line (memory efficient for large files)
    func stream(handler: (GatewayEvent) -> Void) throws {
        guard FileManager.default.fileExists(atPath: eventFileURL.path) else {
            return
        }
        
        let content = try String(contentsOf: eventFileURL, encoding: .utf8)
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        
        for line in lines {
            if let event = parseJSONLine(String(line)) {
                handler(event)
            }
        }
    }
    
    /// Export events to JSON array
    func exportJSON() throws -> String {
        let events = try readAll()
        let data = try JSONEncoder().encode(events)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    /// Export events to CSV
    func exportCSV() throws -> String {
        let events = try readAll()
        
        var csv = "timestamp,event_type,model,request_id,status,duration_ms,message\n"
        for event in events {
            let row = [
                event.timestamp,
                event.eventType.rawValue,
                event.model,
                event.requestID,
                event.status.rawValue,
                String(event.durationMs),
                event.message ?? ""
            ]
            csv += row.map { "\"\($0)\"" }.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    /// Get statistics about events
    func getStats() throws -> EventStatistics {
        let events = try readAll()
        
        let byModel = Dictionary(grouping: events, by: { $0.model })
        let byStatus = Dictionary(grouping: events, by: { $0.status })
        let byType = Dictionary(grouping: events, by: { $0.eventType })
        
        let totalDuration = events.reduce(0) { $0 + $1.durationMs }
        let avgDuration = events.isEmpty ? 0 : totalDuration / events.count
        
        return EventStatistics(
            totalEvents: events.count,
            eventsByModel: byModel.mapValues { $0.count },
            eventsByStatus: byStatus.mapValues { $0.count },
            eventsByType: byType.mapValues { $0.count },
            totalDurationMs: totalDuration,
            averageDurationMs: avgDuration,
            minDurationMs: events.map { $0.durationMs }.min() ?? 0,
            maxDurationMs: events.map { $0.durationMs }.max() ?? 0
        )
    }
    
    /// Count lines (for verification)
    func lineCount() throws -> Int {
        guard FileManager.default.fileExists(atPath: eventFileURL.path) else {
            return 0
        }
        
        let content = try String(contentsOf: eventFileURL, encoding: .utf8)
        return content.split(separator: "\n", omittingEmptySubsequences: true).count
    }
    
    // MARK: - Private
    
    private func parseLines(_ content: String) -> [GatewayEvent] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        return lines.compactMap { parseJSONLine(String($0)) }
    }
    
    private func parseJSONLine(_ line: String) -> GatewayEvent? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GatewayEvent.self, from: data)
    }
}

// MARK: - Statistics

struct EventStatistics: Codable {
    let totalEvents: Int
    let eventsByModel: [String: Int]
    let eventsByStatus: [EventStatus: Int]
    let eventsByType: [EventType: Int]
    let totalDurationMs: Int
    let averageDurationMs: Int
    let minDurationMs: Int
    let maxDurationMs: Int
    
    enum CodingKeys: String, CodingKey {
        case totalEvents = "total_events"
        case eventsByModel = "events_by_model"
        case eventsByStatus = "events_by_status"
        case eventsByType = "events_by_type"
        case totalDurationMs = "total_duration_ms"
        case averageDurationMs = "average_duration_ms"
        case minDurationMs = "min_duration_ms"
        case maxDurationMs = "max_duration_ms"
    }
}
