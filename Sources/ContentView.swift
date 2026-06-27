import SwiftUI

struct ContentView: View {
    @EnvironmentObject var orchestrator: ModelOrchestrator
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var remoteAccess: RemoteAccessManager
    @State private var showingQRCode = false
    
    var body: some View {
        NavigationSplitView {
            // MARK: - Sidebar (Model List)
            List(selection: $orchestrator.selectedModel) {
                if orchestrator.models.isEmpty {
                    Text("No models found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(orchestrator.models) { model in
                        NavigationLink(value: model) {
                            HStack {
                                Image(systemName: model.typeIcon)
                                    .foregroundColor(model.modelType == "VLM" ? .blue : .primary)
                                
                                VStack(alignment: .leading) {
                                    Text(model.name).font(.headline)
                                    Text("\(model.sizeFormatted) • \(model.contextLength) ctx")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if let inst = orchestrator.instances[model.name], inst.isRunning {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { orchestrator.scanModels() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Rescan Models Directory")
                }
            }
            
        } detail: {
            // MARK: - Detail (Console/Control)
            if let selectedModel = orchestrator.selectedModel {
                let isRunning = orchestrator.instances[selectedModel.name]?.isRunning == true
                let logs = orchestrator.instances[selectedModel.name]?.logs ?? []
                
                VStack(spacing: 0) {
                    
                    // Header Status Bar
                    HStack {
                        Circle()
                            .fill(isRunning ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text(isRunning ? "Running" : "Stopped")
                            .font(.headline)
                        
                        Spacer()
                        
                        if isRunning {
                            let url = remoteAccess.bestRemoteURL ?? orchestrator.instances[selectedModel.name]?.serverURL ?? ""
                            Text(url)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            
                            Button(action: { showingQRCode = true }) {
                                Image(systemName: "qrcode")
                            }
                            .help("Show Termux QR Code")
                            .popover(isPresented: $showingQRCode) {
                                QRCodeView(url: url)
                            }
                        }
                        
                        Button(action: { orchestrator.toggleSelected() }) {
                            Text(isRunning ? "Stop" : "Start")
                                .frame(width: 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRunning ? .red : .green)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Console Output
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(logs) { log in
                                    Text(log.text)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(log.color)
                                        .id(log.id)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding()
                        }
                        .background(Color(NSColor.textBackgroundColor))
                        .onChange(of: logs.count) { _, _ in
                            if let last = logs.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    
                    // Footer Bar
                    if let err = orchestrator.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                    }
                    
                }
                .navigationTitle(selectedModel.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { orchestrator.clearLogs() }) {
                            Image(systemName: "trash")
                        }
                        .help("Clear Console logs")
                        .disabled(logs.isEmpty)
                    }
                }
            } else {
                Text("Select a model from the sidebar to begin.")
                    .foregroundColor(.secondary)
            }
        }
    }
}
