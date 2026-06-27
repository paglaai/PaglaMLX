import Foundation
import Combine

@MainActor
final class TunnelManager: ObservableObject {
    static let shared = TunnelManager()
    
    @Published var isEnabled = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "cloudflareTunnelEnabled")
            if isEnabled && RoutingGateway.shared.isRunning {
                start()
            } else if !isEnabled {
                stop()
            }
        }
    }
    @Published var isRunning = false
    @Published var publicURL: String?
    @Published var errorMessage: String?
    
    private var process: Process?
    private var stderrPipe: Pipe?
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "cloudflareTunnelEnabled")
    }
    
    func start() {
        guard isEnabled else { return }
        
        let p = Process()
        
        // Find cloudflared
        let paths = ["/opt/homebrew/bin/cloudflared", "/usr/local/bin/cloudflared"]
        var executable: String?
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                executable = path
                break
            }
        }
        
        guard let exe = executable else {
            errorMessage = "cloudflared not found. Please brew install cloudflared"
            return
        }
        
        let port = SettingsManager.shared.port
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = ["tunnel", "--url", "http://127.0.0.1:\(port)"]
        
        let stderr = Pipe()
        p.standardError = stderr
        
        stderr.fileHandleForReading.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let s = String(data: data, encoding: .utf8) else { return }
            
            // Look for: "https://something.trycloudflare.com"
            if s.contains("trycloudflare.com") {
                let lines = s.split(separator: "\n")
                for line in lines {
                    if let range = line.range(of: "https://[a-zA-Z0-9-]+\\.trycloudflare\\.com", options: .regularExpression) {
                        let url = String(line[range])
                        Task { @MainActor [weak self] in
                            self?.publicURL = url
                            self?.isRunning = true
                            self?.errorMessage = nil
                        }
                    }
                }
            }
        }
        
        p.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.publicURL = nil
            }
        }
        
        do {
            try p.run()
            self.process = p
        } catch {
            errorMessage = "Failed to start tunnel: \(error.localizedDescription)"
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        isRunning = false
        publicURL = nil
    }
}
