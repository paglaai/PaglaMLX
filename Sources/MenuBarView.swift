import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var orchestrator: ModelOrchestrator
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var remoteAccess: RemoteAccessManager
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
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
                            Text(model.name).tag(model as MLXModel?)
                        }
                    }
                }
                .labelsHidden()
                
                let isSelRunning = orchestrator.selectedModel.flatMap { orchestrator.instances[$0.name]?.isRunning } == true
                
                // Server Toggle
                Button(action: { orchestrator.toggleSelected() }) {
                    HStack {
                        Image(systemName: isSelRunning ? "stop.fill" : "play.fill")
                        Text(isSelRunning ? "Stop Server" : "Start Server")
                            .frame(maxWidth: .infinity)
                    }
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
                        .buttonStyle(.plain)
                        .help("Copy URL")
                    }
                    .padding(.top, 4)
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
