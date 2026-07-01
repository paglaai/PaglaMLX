import Foundation
import Observation
import Combine

@MainActor
@Observable final class RemoteAccessManager {
    static let shared = RemoteAccessManager()
    
    var tailscaleIP: String?
    var localIP: String?
    
    private init() {
        refreshIPs()
    }
    
    func refreshIPs() {
        self.tailscaleIP = getTailscaleIP()
        self.localIP = getLocalIP()
    }
    
    private func getTailscaleIP() -> String? {
        // Attempt to read from ifconfig tailscale0
        let task = Process()
        task.launchPath = "/sbin/ifconfig"
        task.arguments = ["tailscale0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse inet 100.x.y.z
                if let range = output.range(of: "inet "),
                   let endRange = output.range(of: " netmask", options: [], range: range.upperBound..<output.endIndex) {
                    let ip = String(output[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    if !ip.isEmpty {
                        return ip
                    }
                }
            }
        } catch {
            print("Failed to run ifconfig for tailscale: \(error)")
        }
        
        // Fallback to tailscale CLI if available
        let cliTask = Process()
        cliTask.launchPath = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        cliTask.arguments = ["ip", "-4"]
        
        let cliPipe = Pipe()
        cliTask.standardOutput = cliPipe
        cliTask.standardError = Pipe()
        
        do {
            try cliTask.run()
            let data = cliPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                return output
            }
        } catch {}
        
        return nil
    }
    
    private func getLocalIP() -> String? {
        let task = Process()
        task.launchPath = "/sbin/ifconfig"
        task.arguments = ["en0"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if let range = output.range(of: "inet "),
                   let endRange = output.range(of: " netmask", options: [], range: range.upperBound..<output.endIndex) {
                    return String(output[range.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}
        
        return nil
    }
    
    var bestRemoteURL: String? {
        let port = SettingsManager.shared.port
        let host = SettingsManager.shared.host
        
        if host == "0.0.0.0" {
            if TunnelManager.shared.isRunning, let cf = TunnelManager.shared.publicURL {
                return cf
            }
            if let ts = tailscaleIP {
                return "http://\(ts):\(port)"
            }
            if let loc = localIP {
                return "http://\(loc):\(port)"
            }
        } else if host != "127.0.0.1" && host != "localhost" {
            // Assume it's a specific bind like Tailscale IP
            return "http://\(host):\(port)"
        }
        
        return nil
    }
}
