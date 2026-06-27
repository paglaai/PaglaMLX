import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct PaglaMLXApp: App {
    @StateObject private var orchestrator = ModelOrchestrator.shared
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var gateway = RoutingGateway.shared
    @StateObject private var proxy = AnthropicProxy.shared
    @StateObject private var remote = RemoteAccessManager.shared
    @StateObject private var tunnel = TunnelManager.shared

    var body: some Scene {
        // MARK: Main Window
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(orchestrator)
                .environmentObject(settings)
                .environmentObject(remote)
                .environmentObject(tunnel)
                .frame(minWidth: 720, minHeight: 520)
                .onAppear {
                    applyActivationPolicy()
                    orchestrator.detectPython()
                    orchestrator.scanModels()
                    // Re-detect Tailscale on launch
                    remote.refreshIPs()
                }
                .onChange(of: settings.hideDockIcon)     { _, _ in applyActivationPolicy() }
                .onChange(of: settings.menuBarMode)      { _, _ in applyActivationPolicy() }
                .onChange(of: settings.modelsDirectory)  { _, _ in orchestrator.scanModels() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Server") {
                Button("Toggle Selected Server") {
                    orchestrator.toggleSelected()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(orchestrator.selectedModel == nil)

                Divider()

                Button("Reveal Models in Finder") {
                    orchestrator.revealModelsInFinder()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Open /v1/models") {
                    orchestrator.openModels()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!gateway.isRunning)
            }
        }

        // MARK: Menu Bar Extra (HIG: .window style for custom UI)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(orchestrator)
                .environmentObject(settings)
                .environmentObject(remote)
        } label: {
            Image(systemName: !orchestrator.instances.filter({ $0.value.isRunning }).isEmpty ? "cpu.fill" : "cpu")
        }
        .menuBarExtraStyle(.window)

        // MARK: Settings Window (⌘,  — handled automatically by SwiftUI)
        Settings {
            SettingsView()
                .environmentObject(orchestrator)
                .environmentObject(settings)
                .environmentObject(tunnel)
        }
    }

    // MARK: - Helpers

    /// Applies the correct activation policy based on menu-bar-mode + hide-dock-icon settings.
    private func applyActivationPolicy() {
        let hide = settings.menuBarMode && settings.hideDockIcon
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
    }
}
