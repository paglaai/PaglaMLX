import SwiftUI

// MARK: - App Launch Phase

enum AppPhase {
    case splash
    case preflight
    case running
}

// MARK: - AppLaunchView

struct AppLaunchView: View {
    @Environment(SettingsManager.self) var settings
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(RemoteAccessManager.self) var remoteAccess

    @State private var phase = AppPhase.splash

    var body: some View {
        switch phase {
        case .splash:
            SplashView {
                withAnimation(.easeOut(duration: 0.3)) {
                    phase = .preflight
                }
            }
        case .preflight:
            PreflightView { allPassed in
                if allPassed {
                    finishLaunch()
                    withAnimation(.easeOut(duration: 0.3)) {
                        phase = .running
                    }
                }
            }
            .transition(.opacity)
        case .running:
            ContentView()
                .transition(.opacity)
        }
    }

    private func finishLaunch() {
        applyActivationPolicy()
        orchestrator.scanModels()
        remoteAccess.refreshIPs()
    }

    private func applyActivationPolicy() {
        let hide = settings.menuBarMode && settings.hideDockIcon
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
    }
}

// MARK: - Splash View

struct SplashView: View {
    let onComplete: () -> Void

    @State private var showText = false
    @State private var progress = 0.0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            SplashLogo()

            Spacer()

            OpenCodeProgress(progress: progress)
                .frame(width: 200)
                .opacity(showText ? 1 : 0)

            TypingText(text: "initializing kernel modules...", delay: 0)
                .opacity(showText ? 1 : 0)
        }
        .frame(width: 520, height: 440)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { showText = true }
            // Animate progress bar then transition
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
                progress += 0.03
                if progress >= 1.0 {
                    t.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                }
            }
        }
    }
}

// MARK: - PreflightView

struct PreflightView: View {
    let onComplete: (Bool) -> Void

    @State private var runner = PreflightRunner(checks: PreflightRunner.defaultChecks())
    @State private var checkStates: [CheckState] = []
    @State private var isRunning = true
    @State private var overallProgress = 0.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuggestion = ""

    private struct CheckState: Identifiable {
        let id: Int
        let name: String
        var status: StatusRow.Status
        var message: String
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("PaglaMLX")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
            }
            .padding(.top, 30)

            OpenCodeProgress(progress: overallProgress)
                .frame(width: 400)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(checkStates) { state in
                    StatusRow(
                        label: state.name,
                        status: state.status,
                        message: state.message
                    )
                    .transition(.opacity.combined(with: .slide))
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            if !isRunning {
                HStack(spacing: 12) {
                    Button("Retry") { restartChecks() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    Button("Quit", role: .destructive) { NSApp.terminate(nil) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .padding(.bottom, 24)
            } else {
                Text("verifying environment...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 520, height: 440)
        .alert("Preflight Check Failed", isPresented: $showAlert) {
            Button("Retry") { restartChecks() }
            Button("Quit", role: .destructive) { NSApp.terminate(nil) }
        } message: {
            Text(alertMessage + (alertSuggestion.isEmpty ? "" : "\n\nSuggestion: \(alertSuggestion)"))
        }
        .onAppear {
            checkStates = runner.checks.enumerated().map { (i, c) in
                CheckState(id: i, name: c.name, status: .pending, message: "")
            }
            runChecks()
        }
    }

    private func runChecks() {
        isRunning = true
        overallProgress = 0
        runner.onCheckCompleted = { index, result in
            let status: StatusRow.Status = switch result.status {
            case .pass:    .pass
            case .warning: .warning
            case .fail:    .fail
            }
            withAnimation(.easeOut(duration: 0.2)) {
                checkStates[index].status  = status
                checkStates[index].message = result.message
                overallProgress = Double(index + 1) / Double(checkStates.count)
            }
        }

        Task {
            let results = await runner.run()
            isRunning = false

            let critical = results.filter { $0.isCritical }
            if critical.isEmpty {
                onComplete(true)
            } else {
                let failures = critical.map { "\($0.check): \($0.message)" }.joined(separator: "\n")
                alertMessage = failures
                alertSuggestion = critical.compactMap { $0.suggestion }.first ?? ""
                showAlert = true
                onComplete(false)
            }
        }
    }

    private func restartChecks() {
        withAnimation {
            checkStates = runner.checks.enumerated().map { (i, c) in
                CheckState(id: i, name: c.name, status: .pending, message: "")
            }
        }
        showAlert = false
        runChecks()
    }
}
