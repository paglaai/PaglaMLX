import Foundation

// MARK: - Result

struct PreflightResult: Equatable {
    let check: String
    let status: Status
    let message: String
    let suggestion: String?

    enum Status: Equatable { case pass, warning, fail }

    var isCritical: Bool { status == .fail }
}

// MARK: - Check Protocol

@MainActor protocol PreflightCheck {
    var name: String { get }
    func run() async -> PreflightResult
}

// MARK: - 1. Model Storage

@MainActor
struct ExternalStorageCheck: PreflightCheck {
    let name = "Model Storage"

    func run() async -> PreflightResult {
        let dir = SettingsManager.shared.modelsDirectory

        guard dir.hasPrefix("/Volumes/") else {
            return .init(check: name, status: .pass,
                         message: "Models directory is on local storage",
                         suggestion: nil)
        }

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)

        if exists && isDir.boolValue {
            return .init(check: name, status: .pass,
                         message: "External volume is mounted",
                         suggestion: nil)
        }

        let volumeName = dir.dropFirst("/Volumes/".count).split(separator: "/").first ?? "external drive"
        return .init(check: name, status: .fail,
                     message: "External volume not mounted at \(dir)",
                     suggestion: "Connect the external drive '\(volumeName)' and ensure it mounts to /Volumes/\(volumeName).")
    }
}

// MARK: - 2. Model Directory

@MainActor
struct ModelDirectoryCheck: PreflightCheck {
    let name = "Model Directory"

    func run() async -> PreflightResult {
        let dir = SettingsManager.shared.modelsDirectory

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir, isDirectory: &isDir)

        guard exists, isDir.boolValue else {
            return .init(check: name, status: .fail,
                         message: "Model directory not found at \(dir)",
                         suggestion: "Verify the path in Settings -> App -> Models Directory, or recreate it.")
        }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        if contents.isEmpty {
            return .init(check: name, status: .warning,
                         message: "Model directory exists but is empty",
                         suggestion: "Place MLX model subdirectories inside \(dir).")
        }

        return .init(check: name, status: .pass,
                     message: "Directory found with \(contents.count) item(s)",
                     suggestion: nil)
    }
}

// MARK: - 3. Python

@MainActor
struct PythonCheck: PreflightCheck {
    let name = "Python"

    func run() async -> PreflightResult {
        let settings = SettingsManager.shared

        if !settings.pythonPath.isEmpty {
            if let version = await queryPythonVersion(settings.pythonPath) {
                settings.pythonStatus = .valid(settings.pythonPath)
                return .init(check: name, status: .pass,
                             message: "Python \(version) at \(settings.pythonPath)",
                             suggestion: nil)
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
            guard FileManager.default.isExecutableFile(atPath: candidate) else { continue }
            if let version = await queryPythonVersion(candidate) {
                settings.pythonPath = candidate
                settings.pythonStatus = .valid(candidate)
                return .init(check: name, status: .pass,
                             message: "Python \(version) at \(candidate)",
                             suggestion: nil)
            }
        }

        settings.pythonStatus = .invalid("No Python found")
        return .init(check: name, status: .fail,
                     message: "No valid Python executable found",
                     suggestion: "Install Python 3.13+ via Homebrew: brew install python")
    }

    nonisolated private func queryPythonVersion(_ path: String) async -> String? {
        await Task.detached(priority: .utility) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = ["--version"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = out
            do {
                try p.run()
                p.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return s?.replacingOccurrences(of: "Python ", with: "")
            } catch {
                return nil
            }
        }.value
    }
}

// MARK: - 4. Virtual Environment

@MainActor
struct VirtualEnvCheck: PreflightCheck {
    let name = "Virtual Environment"

    func run() async -> PreflightResult {
        let settings = SettingsManager.shared
        let pythonPath = settings.pythonPath
        guard !pythonPath.isEmpty else {
            return .init(check: name, status: .fail,
                         message: "No Python path configured – cannot check venv",
                         suggestion: "Ensure Python is configured before running this check.")
        }

        let realPath = resolveRealPath(pythonPath)
        let isVenv = realPath.contains("/.venv/") || realPath.contains("/venv/") || realPath.contains("/.virtualenvs/")

        if isVenv {
            return .init(check: name, status: .pass,
                         message: "Using virtual environment at \(realPath)",
                         suggestion: nil)
        }

        let hasVenvDir = checkVenvInModelDir()
        if hasVenvDir {
            return .init(check: name, status: .warning,
                         message: "Virtual environment directory exists but Python is not using it",
                         suggestion: "Set your pythonPath to the venv's bin/python3.")
        }

        return .init(check: name, status: .pass,
                     message: "System Python – no virtual environment required",
                     suggestion: nil)
    }

    private func resolveRealPath(_ path: String) -> String {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)).map {
            $0.hasPrefix("/") ? $0 : URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent($0).path
        } ?? path
    }

    private func checkVenvInModelDir() -> Bool {
        let dir = SettingsManager.shared.modelsDirectory
        let venvPaths = [dir + "/.venv", dir + "/venv"]
        return venvPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}

// MARK: - 5. Python Packages

@MainActor
struct PackagesCheck: PreflightCheck {
    let name = "Python Packages"

    private let requiredPackages = ["mlx_lm", "fastapi", "uvicorn", "httpx"]

    func run() async -> PreflightResult {
        let pythonPath = SettingsManager.shared.pythonPath
        guard !pythonPath.isEmpty else {
            return .init(check: name, status: .fail,
                         message: "No Python path – cannot check packages",
                         suggestion: "Verify Python is configured.")
        }

        var missing: [String] = []

        for pkg in requiredPackages {
            let installed = await checkPackage(pythonPath, pkg)
            if !installed { missing.append(pkg) }
        }

        if missing.isEmpty {
            return .init(check: name, status: .pass,
                         message: "All required packages are installed",
                         suggestion: nil)
        }

        return .init(check: name, status: .fail,
                     message: "Missing package(s): \(missing.joined(separator: ", "))",
                     suggestion: "Run: pip3 install \(missing.joined(separator: " "))")
    }

    nonisolated private func checkPackage(_ python: String, _ package: String) async -> Bool {
        await Task.detached(priority: .utility) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: python)
            p.arguments = ["-c", "import \(package)"]
            p.standardOutput = Pipe()
            p.standardError = Pipe()
            do {
                try p.run()
                p.waitUntilExit()
                return p.terminationStatus == 0
            } catch { return false }
        }.value
    }
}

// MARK: - 6. Port Availability

@MainActor
struct PortCheck: PreflightCheck {
    let name = "Port Availability"

    func run() async -> PreflightResult {
        let port = SettingsManager.shared.port

        let available = await checkPort(port)
        if available {
            return .init(check: name, status: .pass,
                         message: "Port \(port) is available",
                         suggestion: nil)
        }

        return .init(check: name, status: .fail,
                     message: "Port \(port) is already in use",
                     suggestion: "Change the port in Settings -> Network, or stop the process using port \(port).")
    }

    nonisolated private func checkPort(_ port: Int) async -> Bool {
        await Task.detached(priority: .utility) {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else { return false }
            defer { close(sock) }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = CFSwapInt16HostToBig(UInt16(port))
            addr.sin_addr.s_addr = INADDR_LOOPBACK

            let res = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            return res != 0
        }.value
    }
}

// MARK: - Runner

@MainActor
final class PreflightRunner {
    let checks: [PreflightCheck]

    var onCheckCompleted: ((Int, PreflightResult) -> Void)?

    init(checks: [PreflightCheck]) {
        self.checks = checks
    }

    static func defaultChecks() -> [PreflightCheck] {
        [
            ExternalStorageCheck(),
            ModelDirectoryCheck(),
            PythonCheck(),
            VirtualEnvCheck(),
            PackagesCheck(),
            PortCheck(),
        ]
    }

    func run() async -> [PreflightResult] {
        var results: [PreflightResult] = []
        for (i, check) in checks.enumerated() {
            let result = await check.run()
            results.append(result)
            onCheckCompleted?(i, result)
            if result.isCritical {
                break
            }
        }
        return results
    }
}
