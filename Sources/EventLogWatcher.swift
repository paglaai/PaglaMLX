import Foundation
import Observation

// MARK: - EventLogWatcher
//
// Tails ~/.lengtamlx/events.jsonl in real-time using a kernel-level file
// descriptor source (DispatchSource). Each time the file grows, only the new
// bytes are read, parsed as GatewayEvent, and forwarded to ActivityTracker.shared.

final class EventLogWatcher {
    static let shared = EventLogWatcher()

    private let eventsURL: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var bytesRead: UInt64 = 0
    private let queue = DispatchQueue(label: "com.lengtamlx.eventlogwatcher", qos: .utility)

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        eventsURL = home.appendingPathComponent(".lengtamlx/events.jsonl")
    }

    // MARK: - Lifecycle

    func start() {
        queue.async { [weak self] in
            self?.openAndWatch()
        }
    }

    func stop() {
        source?.cancel()
        if fd >= 0 { Darwin.close(fd) }
        fd = -1
        source = nil
    }

    // MARK: - Private

    private func openAndWatch() {
        // Ensure directory exists
        let dir = eventsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Create file if it doesn't exist yet
        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }

        fd = open(eventsURL.path, O_RDONLY | O_NONBLOCK)
        guard fd >= 0 else {
            print("[EventLogWatcher] Failed to open \(eventsURL.path): \(errno)")
            return
        }

        // Seek to end so we only see NEW events after launch
        bytesRead = UInt64(lseek(fd, 0, SEEK_END))

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.drainNewLines()
        }

        source?.setCancelHandler { [weak self] in
            guard let self = self, self.fd >= 0 else { return }
            Darwin.close(self.fd)
            self.fd = -1
        }

        source?.resume()
    }

    /// Reads any bytes appended since the last read, splits into lines,
    /// decodes each as GatewayEvent and feeds ActivityTracker.
    private func drainNewLines() {
        guard fd >= 0 else { return }

        // How many new bytes?
        var st = stat()
        fstat(fd, &st)
        let fileSize = UInt64(st.st_size)
        guard fileSize > bytesRead else { return }

        let newByteCount = fileSize - bytesRead
        guard newByteCount < 10_000_000 else { return } // sanity cap 10 MB

        var buffer = [UInt8](repeating: 0, count: Int(newByteCount))
        let n = read(fd, &buffer, Int(newByteCount))
        guard n > 0 else { return }
        bytesRead += UInt64(n)

        guard let text = String(bytes: buffer[0..<n], encoding: .utf8) else { return }

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            do {
                let event = try JSONDecoder().decode(GatewayEvent.self, from: data)
                let isError = event.status == .failed
                let latency = Double(event.durationMs)
                let model = event.model

                Task { @MainActor in
                    ActivityTracker.shared.record(
                        modelName: model,
                        tokensPerSecond: 0,   // tokens/s not available in gateway events
                        latencyMs: latency,
                        error: isError
                    )
                }
            } catch {
                // Silently skip malformed lines (e.g. partial writes)
            }
        }
    }
}
