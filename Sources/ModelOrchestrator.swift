import Foundation
import Observation
import SwiftUI
import AppKit

// MARK: - ModelInstance

/// Represents a single running instance of mlx_lm.server
@MainActor
@Observable final class ModelInstance: Identifiable {
    let id = UUID()
    let model: MLXModel
    let port: Int
    
    var isRunning = false
    var logs: [LogEntry] = []
    
    // Health tracking
    enum HealthStatus: String, CaseIterable {
        case unknown = "unknown"
        case healthy = "healthy"
        case degraded = "degraded"
        case unreachable = "unreachable"

        var color: Color {
            switch self {
            case .unknown:     return .gray
            case .healthy:     return .green
            case .degraded:    return .orange
            case .unreachable: return .red
            }
        }
    }
    var healthStatus = HealthStatus.unknown
    var consecutiveHealthFailures = 0
    var lastHealthCheck: Date?

    /// Callback fired when this instance terminates (used by orchestrator to update gateway).
    var onTermination: (() -> Void)?
    
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    
    var serverURL: String { "http://127.0.0.1:\(port)" }
    
    init(model: MLXModel, port: Int) {
        self.model = model
        self.port = port
    }
    
    func start() {
        let settings = SettingsManager.shared
        guard !settings.pythonPath.isEmpty else {
            append("❌ No Python configured — open Settings → Python.", level: .error)
            return
        }
        
        let p = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        
        var args: [String] = [
            "-m", "mlx_lm.server",
            "--model",      model.path,
            "--port",       "\(port)",
            "--host",       "127.0.0.1", // Internal instances bind locally; Gateway handles external
            "--temp",       fmt(settings.temp),
            "--top-p",      fmt(settings.topP),
            "--max-tokens", "\(settings.maxTokens)",
            "--log-level",  settings.logLevel.rawValue,
        ]
        if settings.topK > 0              { args += ["--top-k", "\(settings.topK)"] }
        if settings.minP > 0              { args += ["--min-p", fmt(settings.minP)] }
        if settings.trustRemoteCode       { args += ["--trust-remote-code"] }
        let tca = settings.chatTemplateArgs.trimmingCharacters(in: .whitespaces)
        if !tca.isEmpty                   { args += ["--chat-template-args", tca] }
        if settings.promptCacheSize  > 0  { args += ["--prompt-cache-size",  "\(settings.promptCacheSize)"] }
        if settings.promptCacheBytes > 0  { args += ["--prompt-cache-bytes", "\(settings.promptCacheBytes)"] }
        
        p.executableURL = URL(fileURLWithPath: settings.pythonPath)
        p.arguments     = args
        
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/Library/Frameworks/Python.framework/Versions/3.14/bin"
                       + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        env["PATH"] = extraPaths + ":" + (env["PATH"] ?? "")
        if !env.keys.contains("HF_HUB_CACHE") {
            env["HF_HUB_CACHE"] = "/Volumes/CastingC0UCH/M0DEL/HF_CACHE"
        }
        p.environment = env
        
        p.standardOutput = stdout
        p.standardError  = stderr
        
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                let ok = proc.terminationStatus == 0
                self?.append("Server exited (code \(proc.terminationStatus))",
                             level: ok ? .info : .error)
                self?.onTermination?()
            }
        }
        
        stdout.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            Task { @MainActor [weak self] in
                self?.logs.append(contentsOf: lines.map { LogEntry($0, level: .info) })
            }
        }
        
        stderr.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            let lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            Task { @MainActor [weak self] in
                self?.logs.append(contentsOf: lines.map { LogEntry($0, level: .stderr) })
            }
        }
        
        do {
            try p.run()
            process    = p
            stdoutPipe = stdout
            stderrPipe = stderr
            isRunning  = true
            append("✅ Instance running — \(serverURL)", level: .success)
            append("   " + args.joined(separator: " "),  level: .detail)
        } catch {
            append("❌ Failed to start: \(error.localizedDescription)", level: .error)
        }
    }
    
    func stop() {
        process?.terminate()
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil; stdoutPipe = nil; stderrPipe = nil
        isRunning = false
        append("⏹ Instance stopped.", level: .info)
    }
    
    func clearLogs() { logs = [] }

    func performHealthCheck() async {
        let url = URL(string: "http://127.0.0.1:\(port)/v1/models")!
        var request = URLRequest(url: url, timeoutInterval: 5)
        let apiKey = await Task { @MainActor in SettingsManager.shared.apiKey }.value
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if ok {
                consecutiveHealthFailures = 0
                healthStatus = .healthy
            } else {
                consecutiveHealthFailures += 1
                healthStatus = consecutiveHealthFailures >= 3 ? .unreachable : .degraded
            }
        } catch {
            consecutiveHealthFailures += 1
            healthStatus = consecutiveHealthFailures >= 3 ? .unreachable : .degraded
        }
        lastHealthCheck = Date()
    }
    
    private func append(_ text: String, level: LogEntry.Level) {
        logs.append(LogEntry(text, level: level))
    }
    
    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%g", v)
    }
}

// MARK: - ModelOrchestrator

@MainActor
@Observable final class ModelOrchestrator {
    static let shared = ModelOrchestrator()
    
    var models: [MLXModel] = []
    var selectedModel: MLXModel?
    var instances: [String: ModelInstance] = [:]
    var errorMessage: String?
    
    private var nextPort = 8000
    private var healthTimer: Timer?
    
    // Fallback references for views migrating from ServerManager
    var isRunning: Bool {
        guard let sel = selectedModel, let inst = instances[sel.name] else { return false }
        return inst.isRunning
    }
    var logs: [LogEntry] {
        guard let sel = selectedModel, let inst = instances[sel.name] else { return [] }
        return inst.logs
    }
    
    private init() {}
    
    func toggleSelected() {
        guard let sel = selectedModel else { return }
        if let inst = instances[sel.name], inst.isRunning {
            inst.stop()
        } else {
            start(model: sel)
        }
    }
    
    @discardableResult
    func start(model: MLXModel) -> ModelInstance {
        if let existing = instances[model.name] {
            if !existing.isRunning {
                if let err = preflightCheck(for: model) {
                    existing.logs.append(LogEntry("❌ Preflight Failed: \(err)", level: .error))
                    errorMessage = err
                    return existing
                }
                existing.start()
            }
            return existing
        }
        
        let newInstance = ModelInstance(model: model, port: nextPort)
        nextPort += 1
        instances[model.name] = newInstance
        
        if let err = preflightCheck(for: model) {
            newInstance.logs.append(LogEntry("❌ Preflight Failed: \(err)", level: .error))
            errorMessage = err
            return newInstance
        }
        
        newInstance.start()

        startHealthPolling()
        updateGateway()
        
        // Update gateway routing when this instance terminates
        newInstance.onTermination = { [weak self] in
            self?.updateGateway()
        }
        
        return newInstance
    }
    
    func stop(model: MLXModel) {
        instances[model.name]?.stop()
        updateGateway()
    }
    
    private func preflightCheck(for model: MLXModel) -> String? {
        let settings = SettingsManager.shared
        // 1. Python Path
        if settings.pythonPath.isEmpty || !FileManager.default.fileExists(atPath: settings.pythonPath) {
            return "Python executable is missing or invalid. Please configure it in Settings."
        }
        
        // 2. Memory Heuristics (Apple Silicon)
        let totalMemGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024
        // Just a basic warning, not necessarily a hard block unless memory is exceptionally low.
        if totalMemGB < 8 {
            print("Warning: Running on <8GB RAM")
        }
        
        // 3. Routing Table Size Check
        let runningCount = instances.values.filter { $0.isRunning }.count
        if runningCount >= 3 {
            return "Too many models running (\(runningCount)). Free up memory by stopping one."
        }
        
        return nil
    }
    
    private func updateGateway() {
        // Collect mapping of ModelName -> metadata for all running instances
        var routes: [String: [String: Any]] = [:]
        for (name, inst) in instances where inst.isRunning {
            routes[name] = [
                "port": inst.port,
                "context_length": inst.model.contextLength,
                "model_type": inst.model.modelType
            ]
        }
        
        RoutingGateway.shared.updateRoutingTable(routes)
        
        if routes.isEmpty {
            RoutingGateway.shared.stop()
            stopHealthPolling()
        } else if !RoutingGateway.shared.isRunning {
            RoutingGateway.shared.start()
            startHealthPolling()
        }
    }
    
    func clearLogs() {
        guard let sel = selectedModel else { return }
        instances[sel.name]?.clearLogs()
    }

    // MARK: - Health Polling

    func startHealthPolling() {
        healthTimer?.invalidate()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollHealth()
            }
        }
        // Fire immediately for first check
        Task { await pollHealth() }
    }

    func stopHealthPolling() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    private func pollHealth() async {
        for (_, inst) in instances where inst.isRunning {
            await inst.performHealthCheck()
        }
    }
    
    // MARK: - Scanning & Python (migrated from ServerManager)
    
    func detectPython() {
        let settings = SettingsManager.shared
        Task {
            settings.pythonStatus = .checking
            if !settings.pythonPath.isEmpty {
                if await validatePython(at: settings.pythonPath) {
                    settings.pythonStatus = .valid(settings.pythonPath)
                    return
                }
            }
            let candidates = [
                "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3",
                "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
                "/opt/homebrew/bin/python3",
                "/usr/local/bin/python3",
                "/usr/bin/python3",
            ]
            for candidate in candidates {
                if FileManager.default.isExecutableFile(atPath: candidate),
                   await validatePython(at: candidate) {
                    settings.pythonPath = candidate
                    settings.pythonStatus = .valid(candidate)
                    return
                }
            }
            settings.pythonStatus = .invalid("No Python with mlx_lm found.")
        }
    }
    
    nonisolated private func validatePython(at path: String) async -> Bool {
        await Task.detached(priority: .utility) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            proc.arguments     = ["-c", "import mlx_lm"]
            do {
                try proc.run()
                proc.waitUntilExit()
                return proc.terminationStatus == 0
            } catch { return false }
        }.value
    }
    
    func scanModels() {
        let settings = SettingsManager.shared
        let dirURL = URL(fileURLWithPath: settings.modelsDirectory)
        errorMessage = nil
        let fm = FileManager.default
        
        do {
            let contents = try fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            models = contents.filter { url in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }.compactMap { url -> MLXModel? in
                let name = url.lastPathComponent
                let configPath = url.appendingPathComponent("config.json")
                var contextLength = 4096
                var modelType = "LLM"
                if let data = try? Data(contentsOf: configPath),
                   let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    contextLength = config["max_position_embeddings"] as? Int ?? contextLength
                    if let arch = config["architectures"] as? [String],
                       arch.contains(where: { $0.lowercased().contains("vl") || $0.lowercased().contains("vision") }) {
                        modelType = "VLM"
                    }
                }
                // Mock size to avoid slow directorySize on main thread
                return MLXModel(name: name, path: url.path, sizeGB: 0.0, contextLength: contextLength, modelType: modelType)
            }.sorted { $0.name < $1.name }
            
            if selectedModel == nil, let first = models.first {
                selectedModel = first
            }
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSFileNoSuchFileError {
                errorMessage = "Model directory not found at \(settings.modelsDirectory). Go to Settings → App → Models Directory and set the correct path."
            } else {
                errorMessage = "Failed to scan: \(error.localizedDescription)"
            }
            models = []
        }
    }
    
    func revealModelsInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: SettingsManager.shared.modelsDirectory)
    }
    
    func openModels() {
        // Will point to Gateway URL in the future
        guard let url = URL(string: "http://127.0.0.1:\(SettingsManager.shared.port)/v1/models") else { return }
        NSWorkspace.shared.open(url)
    }
}

