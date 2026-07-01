import SwiftUI

struct MenuBarView: View {
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(SettingsManager.self) var settings
    @Environment(RemoteAccessManager.self) var remoteAccess
    @Environment(\.openWindow) var openWindow
    @State private var benchmark = BenchmarkManager.shared

    var body: some View {
        @Bindable var orchestrator = orchestrator
        @Bindable var settings = settings
        @Bindable var remoteAccess = remoteAccess
        @Bindable var benchmark = benchmark
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header
            HStack {
                Text("PaglaMLX")
                    .font(.headline)
                Spacer()

                let anyRunning = !orchestrator.instances.filter({ $0.value.isRunning }).isEmpty
                Circle()
                    .fill(anyRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(anyRunning ? "Running" : "Stopped")
                    .font(.subheadline)
                    .foregroundColor(anyRunning ? .green : .red)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // MARK: Controls
            VStack(alignment: .leading, spacing: 12) {

                // Model Picker
                Picker("Model", selection: $orchestrator.selectedModel) {
                    if orchestrator.models.isEmpty {
                        Text("No models found").tag(nil as MLXModel?)
                    } else {
                        ForEach(orchestrator.models) { model in
                            HStack {
                                Text(model.name)
                                if let inst = orchestrator.instances[model.name], inst.isRunning {
                                    Circle()
                                        .fill(inst.healthStatus.color)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .tag(model as MLXModel?)
                        }
                    }
                }
                .labelsHidden()

                let sel = orchestrator.selectedModel
                let inst = sel.flatMap { orchestrator.instances[$0.name] }
                let isSelRunning = inst?.isRunning == true

                // Server Toggle
                Button(action: { orchestrator.toggleSelected() }) {
                    Label(isSelRunning ? "Stop Server" : "Start Server", systemImage: isSelRunning ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isSelRunning ? .red : .blue)
                .disabled(orchestrator.selectedModel == nil)

                if let sel = orchestrator.selectedModel, isSelRunning {
                    HStack {
                        Text("URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        let url = remoteAccess.bestRemoteURL ?? orchestrator.instances[sel.name]?.serverURL ?? ""
                        Text(url)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel("Copy URL")
                        .buttonStyle(.plain)
                        .help("Copy URL")
                    }
                    .padding(.top, 4)

                    // Health + Benchmark row
                    if let instance = inst {
                        HStack {
                            Circle()
                                .fill(instance.healthStatus.color)
                                .frame(width: 6, height: 6)
                            Text(instance.healthStatus.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundColor(instance.healthStatus.color)

                            Spacer()

                            if let last = benchmark.results.first(where: { $0.modelName == sel.name }) {
                                Text("\(String(format: "%.1f", last.tokensPerSecond)) t/s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Button(action: {
                                benchmark.runBenchmark(model: sel, port: instance.port, apiKey: settings.apiKey)
                            }) {
                                Image(systemName: "gauge")
                                    .font(.caption)
                            }
                            .disabled(benchmark.isRunning)
                            .buttonStyle(.plain)
                            .help("Run benchmark")
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding()

            Divider()

            // MARK: Actions
            VStack(spacing: 4) {
                Button(action: { openWindow(id: "main") }) {
                    HStack {
                        Text("Open Main Window")
                        Spacer()
                        Image(systemName: "macwindow")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    if #available(macOS 13.0, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }) {
                    HStack {
                        Text("Settings…")
                        Spacer()
                        Image(systemName: "gear")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.vertical, 4)

                Button(action: { NSApp.terminate(nil) }) {
                    HStack {
                        Text("Quit PaglaMLX")
                        Spacer()
                        Text("⌘Q").foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 300)
    }
}
