import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct PaglaMLXApp: App {
    @State private var orchestrator = ModelOrchestrator.shared
    @State private var settings = SettingsManager.shared
    @State private var gateway = RoutingGateway.shared
    @State private var proxy = AnthropicProxy.shared
    @State private var remote = RemoteAccessManager.shared
    @State private var tunnel = TunnelManager.shared

    var body: some Scene {
        // MARK: Main Window
        WindowGroup(id: "main") {
            AppLaunchView()
                .environment(orchestrator)
                .environment(settings)
                .environment(remote)
                .environment(tunnel)
                .frame(minWidth: 800, idealWidth: 960, minHeight: 600, idealHeight: 680)
                .onChange(of: settings.hideDockIcon)     { _, _ in applyActivationPolicy() }
                .onChange(of: settings.menuBarMode)      { _, _ in applyActivationPolicy() }
                .onChange(of: settings.modelsDirectory)  { _, _ in orchestrator.scanModels() }
                .onAppear { EventLogWatcher.shared.start() }
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
                .environment(orchestrator)
                .environment(settings)
                .environment(remote)
        } label: {
            Image(systemName: !orchestrator.instances.filter({ $0.value.isRunning }).isEmpty ? "cpu.fill" : "cpu")
        }
        .menuBarExtraStyle(.window)

        // MARK: Settings Window (⌘,  — handled automatically by SwiftUI)
        Settings {
            SettingsView()
                .environment(orchestrator)
                .environment(settings)
                .environment(tunnel)
        }
    }

    // MARK: - Helpers

    /// Applies the correct activation policy based on menu-bar-mode + hide-dock-icon settings.
    private func applyActivationPolicy() {
        let hide = settings.menuBarMode && settings.hideDockIcon
        NSApp.setActivationPolicy(hide ? .accessory : .regular)
    }
}
