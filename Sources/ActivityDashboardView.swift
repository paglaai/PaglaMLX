import SwiftUI

struct ActivityDashboardView: View {
    @Environment(ModelOrchestrator.self) var orchestrator
    @Environment(SettingsManager.self) var settings
    @State private var activity = ActivityTracker.shared
    @State private var systemMonitor = SystemMonitorManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {

                // MARK: - System Health
                GroupBox(label: Label("System Health", systemImage: "gauge")) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        healthRow(
                            icon: "thermometer",
                            label: "Thermal State",
                            value: systemMonitor.thermalLevel.rawValue,
                            color: systemMonitor.thermalLevel.color
                        )
                        Divider()
                        healthRow(
                            icon: "memorychip",
                            label: "Memory Used",
                            value: String(format: "%.1f / %.1f GB", systemMonitor.usedMemoryGB, systemMonitor.totalMemoryGB),
                            color: systemMonitor.memoryPressureColor
                        )
                        Divider()
                        healthRow(
                            icon: "gauge",
                            label: "Memory Pressure",
                            value: systemMonitor.memoryStatusText,
                            color: systemMonitor.memoryPressureColor
                        )
                    }
                    .padding(DesignTokens.Spacing.md)
                }

                // MARK: - Request Metrics
                GroupBox(label: Label("Request Metrics", systemImage: "chart.bar")) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        metricRow("Total Requests",     value: "\(activity.totalRequests)")
                        metricRow("Total Errors",       value: "\(activity.totalErrors)", color: activity.totalErrors > 0 ? .orange : .secondary)
                        metricRow("Avg Tok/s",          value: String(format: "%.1f", activity.averageTokensPerSecond))
                        metricRow("Avg Latency",        value: String(format: "%.0f ms", activity.averageLatencyMs))
                        Divider()
                        metricRow("Requests / min",     value: "\(activity.requestsLastMinute)")
                        metricRow("Errors / min",       value: "\(activity.errorsLastMinute)", color: activity.errorsLastMinute > 0 ? .red : .secondary)

                        if !activity.recentRequests.isEmpty {
                            Divider()
                            Text("Last 50 Requests")
                                .font(DesignTokens.Font.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(activity.recentRequests.reversed()) { record in
                                HStack(spacing: DesignTokens.Spacing.sm) {
                                    Circle()
                                        .fill(record.error ? Color.red : Color.green)
                                        .frame(width: 6, height: 6)
                                    Text(record.modelName)
                                        .font(DesignTokens.Font.monospacedSmall)
                                        .frame(width: 100, alignment: .leading)
                                        .lineLimit(1)
                                    Text(String(format: "%.1f t/s", record.tokensPerSecond))
                                        .font(DesignTokens.Font.monospacedSmall)
                                        .frame(width: 70, alignment: .trailing)
                                    Text(String(format: "%.0f ms", record.latencyMs))
                                        .font(DesignTokens.Font.monospacedSmall)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(record.timestamp, style: .time)
                                        .font(DesignTokens.Font.monospacedSmall)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                }

                // MARK: - Running Models
                GroupBox(label: Label("Running Models", systemImage: "cpu")) {
                    if orchestrator.instances.filter({ $0.value.isRunning }).isEmpty {
                        Text("No models running")
                            .font(DesignTokens.Font.body)
                            .foregroundColor(.secondary)
                            .padding(DesignTokens.Spacing.md)
                    } else {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            ForEach(Array(orchestrator.instances.filter { $0.value.isRunning }), id: \.key) { name, inst in
                                HStack {
                                    Circle()
                                        .fill(inst.healthStatus.color)
                                        .frame(width: 8, height: 8)
                                    Text(name)
                                        .font(DesignTokens.Font.subheadline)
                                    Spacer()
                                    Text("Port \(inst.port)")
                                        .font(DesignTokens.Font.monospacedSmall)
                                        .foregroundColor(.secondary)
                                    Text(inst.warmPoolActive ? "🔥" : "")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xxl)
        }
        .onAppear {
            systemMonitor.startMonitoring()
        }
        .onDisappear {
            systemMonitor.stopMonitoring()
        }
    }

    private func healthRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(label)
                .font(DesignTokens.Font.body)
            Spacer()
            Text(value)
                .font(DesignTokens.Font.monospacedSubhead)
                .foregroundColor(color)
        }
    }

    private func metricRow(_ label: String, value: String, color: Color = .secondary) -> some View {
        HStack {
            Text(label)
                .font(DesignTokens.Font.body)
            Spacer()
            Text(value)
                .font(DesignTokens.Font.monospacedSubhead)
                .foregroundColor(color)
        }
    }
}
