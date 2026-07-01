import SwiftUI

// MARK: - App Launch Phase

enum AppPhase {
    case preflight
    case running
}

// MARK: - AppLaunchView

struct AppLaunchView: View {
    @Environment(SettingsManager.self) var settings
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(RemoteAccessManager.self) var remoteAccess

    @State private var phase = AppPhase.preflight

    var body: some View {
        switch phase {
        case .preflight:
            PreflightView { allPassed in
                if allPassed {
                    finishLaunch()
                    phase = .running
                }
            }
        case .running:
            ContentView()
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

// MARK: - PreflightView

struct PreflightView: View {
    let onComplete: (Bool) -> Void

    @State private var runner = PreflightRunner(checks: PreflightRunner.defaultChecks())
    @State private var checkStates: [CheckState] = []
    @State private var isRunning = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuggestion = ""

    private struct CheckState: Identifiable {
        let id: Int
        let name: String
        var status: Status
        var message: String

        enum Status { case pending, running, pass, warning, fail }

        var iconName: String {
            switch status {
            case .pending: return "circle"
            case .running: return "arrow.triangle.2.circlepath"
            case .pass:    return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .fail:    return "xmark.circle.fill"
            }
        }

        var iconColor: Color {
            switch status {
            case .pending: return .secondary
            case .running: return .blue
            case .pass:    return .green
            case .warning: return .orange
            case .fail:    return .red
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                Text("PaglaMLX")
                    .font(.largeTitle).bold()
                Text("Checking your environment…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(checkStates) { state in
                    HStack(spacing: 10) {
                        Group {
                            if state.status == .running {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: state.iconName)
                                    .foregroundStyle(state.iconColor)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(width: 20)

                        Text(state.name)
                            .font(.body)
                            .foregroundColor(state.status == .pending ? .secondary : .primary)

                        Spacer()

                        if !state.message.isEmpty {
                            Text(state.message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
            .padding(.horizontal, 40)

            if !isRunning {
                Button("Retry") {
                    restartChecks()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 20)
            } else {
                Spacer().frame(height: 60)
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
        runner.onCheckCompleted = { [self] index, result in
            let status: CheckState.Status = switch result.status {
            case .pass:    .pass
            case .warning: .warning
            case .fail:    .fail
            }
            checkStates[index].status  = status
            checkStates[index].message = result.message
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
        checkStates = runner.checks.enumerated().map { (i, c) in
            CheckState(id: i, name: c.name, status: .pending, message: "")
        }
        showAlert = false
        runChecks()
    }
}
