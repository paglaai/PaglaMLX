import Foundation
import SwiftUI
import Observation

@MainActor
@Observable final class SystemMonitorManager {
    static let shared = SystemMonitorManager()

    // Thermal
    enum ThermalLevel: String, CaseIterable {
        case unknown = "Unknown"
        case nominal = "Nominal"
        case fair    = "Fair"
        case serious = "Serious"
        case critical = "Critical"

        var color: Color {
            switch self {
            case .unknown:  return .gray
            case .nominal:  return .green
            case .fair:     return .yellow
            case .serious:  return .orange
            case .critical: return .red
            }
        }
    }
    var thermalLevel = ThermalLevel.unknown

    // Memory
    var usedMemoryGB: Double = 0
    var totalMemoryGB: Double = 0
    var memoryPressure: Double = 0
    var swapUsedGB: Double = 0

    private var timer: Timer?

    private init() {}

    func startMonitoring() {
        totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        update()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.update()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        // Thermal state via ProcessInfo
        let thermal = ProcessInfo.processInfo.thermalState
        switch thermal {
        case .nominal:  thermalLevel = .nominal
        case .fair:     thermalLevel = .fair
        case .serious:  thermalLevel = .serious
        case .critical: thermalLevel = .critical
        @unknown default: thermalLevel = .unknown
        }

        // Memory via sysctl / vm_stat
        updateMemoryStats()
    }

    private func updateMemoryStats() {
        var vmStats = vm_statistics_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()

        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_VM_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let pageSize = vm_kernel_page_size
        let active = Double(vmStats.active_count) * Double(pageSize)
        let wired  = Double(vmStats.wire_count)  * Double(pageSize)
        let total  = Double(ProcessInfo.processInfo.physicalMemory)

        usedMemoryGB   = (active + wired) / 1_073_741_824
        memoryPressure = usedMemoryGB / (Double(total) / 1_073_741_824)
    }

    var memoryPressureColor: Color {
        switch memoryPressure {
        case ..<0.6:  return .green
        case ..<0.8:  return .yellow
        case ..<0.9:  return .orange
        default:       return .red
        }
    }

    var memoryStatusText: String {
        if memoryPressure < 0.6 {
            return "OK"
        } else if memoryPressure < 0.8 {
            return "Elevated"
        } else if memoryPressure < 0.9 {
            return "High"
        } else {
            return "Critical"
        }
    }
}
