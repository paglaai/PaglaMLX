import Foundation

/// ReplayTests: Deterministic event stream replay validation
/// Records N synthetic events → replays them → verifies ordering, count, and content integrity

import XCTest

class EventReplayTests: XCTestCase {
    var recorder: EventRecorder!
    var reader: EventReader!
    var tempFileURL: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary test file
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("test-events-\(UUID().uuidString).jsonl")
        
        recorder = EventRecorder(customPath: tempFileURL)
        reader = EventReader(customPath: tempFileURL)
    }
    
    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: tempFileURL)
    }
    
    // MARK: - Basic Recording Tests
    
    func testRecordSingleEvent() throws {
        recorder.record(
            eventType: .request,
            model: "llama-2-7b",
            requestID: "req_001",
            status: .success,
            durationMs: 1250
        )
        
        let events = try reader.readAll()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].model, "llama-2-7b")
        XCTAssertEqual(events[0].status, .success)
    }
    
    func testRecordMultipleEvents() throws {
        for i in 0..<10 {
            recorder.record(
                eventType: .request,
                model: "model-\(i % 3)",
                requestID: "req_\(String(format: "%03d", i))",
                status: i % 2 == 0 ? .success : .failed,
                durationMs: Int.random(in: 100...5000)
            )
        }
        
        let events = try reader.readAll()
        XCTAssertEqual(events.count, 10)
    }
    
    // MARK: - Deterministic Replay Tests (1000 events)
    
    func testDeterministicReplay1000Events() throws {
        let eventCount = 1000
        var recordedSequence: [(id: String, timestamp: String, model: String)] = []
        
        // Phase 1: Record synthetic events
        for i in 0..<eventCount {
            let eventID = "synthetic_\(String(format: "%06d", i))"
            let model = ["gpt-4", "llama-2-7b", "mistral-7b"][i % 3]
            let status: EventStatus = i % 10 == 0 ? .failed : .success
            
            recorder.record(
                eventType: .request,
                model: model,
                requestID: eventID,
                status: status,
                durationMs: 500 + (i % 100)
            )
            
            recordedSequence.append((id: eventID, timestamp: "", model: model))
        }
        
        // Phase 2: Replay - read all events back
        let replayedEvents = try reader.readAll()
        
        // Phase 3: Verify
        XCTAssertEqual(replayedEvents.count, eventCount, "Replay count mismatch")
        
        // Verify order is preserved
        for (index, event) in replayedEvents.enumerated() {
            XCTAssertEqual(
                event.requestID,
                recordedSequence[index].id,
                "Event \(index) ID mismatch: expected \(recordedSequence[index].id), got \(event.requestID)"
            )
            XCTAssertEqual(
                event.model,
                recordedSequence[index].model,
                "Event \(index) model mismatch"
            )
        }
        
        // Verify timestamps are in ascending order
        let timestamps = replayedEvents.map { $0.timestamp }
        let sortedTimestamps = timestamps.sorted()
        XCTAssertEqual(timestamps, sortedTimestamps, "Timestamps not in ascending order")
    }
    
    // MARK: - Filtering & Querying Tests
    
    func testQueryByModel() throws {
        let models = ["gpt-4", "llama-2-7b", "mistral-7b"]
        
        for i in 0..<30 {
            recorder.record(
                eventType: .request,
                model: models[i % 3],
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100
            )
        }
        
        let gpt4Events = try reader.query(model: "gpt-4")
        XCTAssertEqual(gpt4Events.count, 10, "Expected 10 gpt-4 events")
        XCTAssertTrue(gpt4Events.allSatisfy { $0.model == "gpt-4" })
    }
    
    func testQueryByStatus() throws {
        for i in 0..<20 {
            recorder.record(
                eventType: .request,
                model: "test-model",
                requestID: "req_\(i)",
                status: i % 2 == 0 ? .success : .failed,
                durationMs: 100
            )
        }
        
        let successEvents = try reader.query(status: .success)
        let failedEvents = try reader.query(status: .failed)
        
        XCTAssertEqual(successEvents.count, 10)
        XCTAssertEqual(failedEvents.count, 10)
    }
    
    func testQueryByEventType() throws {
        // Record mixed event types
        recorder.recordModelLifecycle(action: .load, model: "model-1", durationMs: 500)
        
        for _ in 0..<5 {
            recorder.record(
                eventType: .request,
                model: "model-1",
                requestID: UUID().uuidString,
                status: .success,
                durationMs: 100
            )
        }
        
        recorder.recordModelLifecycle(action: .unload, model: "model-1", durationMs: 200)
        
        let loadEvents = try reader.query(eventType: .modelLoad)
        let requestEvents = try reader.query(eventType: .request)
        let unloadEvents = try reader.query(eventType: .modelUnload)
        
        XCTAssertEqual(loadEvents.count, 1)
        XCTAssertEqual(requestEvents.count, 5)
        XCTAssertEqual(unloadEvents.count, 1)
    }
    
    // MARK: - Export Tests
    
    func testExportToJSON() throws {
        for i in 0..<5 {
            recorder.record(
                eventType: .request,
                model: "test",
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100
            )
        }
        
        let json = try reader.exportJSON()
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([GatewayEvent].self, from: data)
        
        XCTAssertEqual(decoded.count, 5)
    }
    
    func testExportToCSV() throws {
        for i in 0..<3 {
            recorder.record(
                eventType: .request,
                model: "test-model",
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100 + i * 50,
                message: "Test message \(i)"
            )
        }
        
        let csv = try reader.exportCSV()
        let lines = csv.split(separator: "\n")
        
        XCTAssertEqual(lines.count, 4, "Expected header + 3 data rows")
        XCTAssertTrue(lines[0].contains("timestamp,event_type,model"))
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() throws {
        // Record with specific patterns
        for i in 0..<10 {
            let model = i < 5 ? "model-A" : "model-B"
            let status: EventStatus = i % 3 == 0 ? .failed : .success
            
            recorder.record(
                eventType: .request,
                model: model,
                requestID: "req_\(i)",
                status: status,
                durationMs: 1000 + (i * 100)
            )
        }
        
        let stats = try reader.getStats()
        
        XCTAssertEqual(stats.totalEvents, 10)
        XCTAssertEqual(stats.eventsByModel["model-A"], 5)
        XCTAssertEqual(stats.eventsByModel["model-B"], 5)
        XCTAssertGreaterThan(stats.totalDurationMs, 0)
        XCTAssertGreaterThan(stats.averageDurationMs, 0)
    }
    
    // MARK: - Concurrent Write Tests
    
    func testConcurrentWrites() throws {
        let queue = DispatchQueue(label: "concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<100 {
            queue.async(group: group) { [weak self] in
                self?.recorder.record(
                    eventType: .request,
                    model: "concurrent-test",
                    requestID: "req_concurrent_\(i)",
                    status: .success,
                    durationMs: 100
                )
            }
        }
        
        group.waitWithTimeout(seconds: 5)
        
        let events = try reader.readAll()
        XCTAssertEqual(events.count, 100, "All concurrent writes should succeed")
    }
    
    // MARK: - Append-Only Verification
    
    func testAppendOnly() throws {
        // Write 10 events
        for i in 0..<10 {
            recorder.record(
                eventType: .request,
                model: "append-test",
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100
            )
        }
        
        let firstRead = try reader.readAll()
        XCTAssertEqual(firstRead.count, 10)
        
        // Write 5 more events (don't create new recorder)
        for i in 10..<15 {
            recorder.record(
                eventType: .request,
                model: "append-test",
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100
            )
        }
        
        let secondRead = try reader.readAll()
        XCTAssertEqual(secondRead.count, 15, "Events should be appended, not replaced")
        
        // Verify original events are intact
        for i in 0..<10 {
            XCTAssertEqual(secondRead[i].requestID, "req_\(i)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFile() throws {
        let events = try reader.readAll()
        XCTAssertEqual(events.count, 0)
        
        let stats = try reader.getStats()
        XCTAssertEqual(stats.totalEvents, 0)
    }
    
    func testRecordWithNilMessage() throws {
        recorder.record(
            eventType: .request,
            model: "test",
            requestID: "req_nil_msg",
            status: .success,
            durationMs: 100,
            message: nil
        )
        
        let events = try reader.readAll()
        XCTAssertEqual(events[0].message, nil)
    }
    
    func testLineCount() throws {
        for i in 0..<7 {
            recorder.record(
                eventType: .request,
                model: "test",
                requestID: "req_\(i)",
                status: .success,
                durationMs: 100
            )
        }
        
        let lineCount = try reader.lineCount()
        XCTAssertEqual(lineCount, 7)
    }
}

// MARK: - Test Helpers

extension DispatchGroup {
    func waitWithTimeout(seconds: Double) {
        let result = wait(timeout: .now() + seconds)
        if result == .timedOut {
            print("Warning: DispatchGroup timed out after \(seconds)s")
        }
    }
}
