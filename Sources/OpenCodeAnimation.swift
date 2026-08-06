import SwiftUI

// MARK: - Spinning Dots (openCODE style)

struct SpinningDots: View {
    let count: Int
    let activeIndex: Int
    let color: Color

    init(count: Int = 3, activeIndex: Int = 0, color: Color = .blue) {
        self.count = count
        self.activeIndex = activeIndex
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == activeIndex ? color : color.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .scaleEffect(i == activeIndex ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: activeIndex)
            }
        }
    }
}

// MARK: - Animated Spinner (three-dot bounce)

struct BouncingDots: View {
    @State private var phase = 0

    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1 : 0.25)
                    .scaleEffect(phase == i ? 1.3 : 0.7)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { t in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Typing Text Effect

struct TypingText: View {
    let text: String
    let delay: Double

    @State private var displayed: String = ""
    @State private var cursor = true

    var body: some View {
        HStack(spacing: 0) {
            Text(displayed)
                .font(.system(.caption, design: .monospaced))
            Text(cursor ? "|" : " ")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.blue)
        }
        .onAppear {
            type()
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                cursor.toggle()
            }
        }
    }

    private func type() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for (i, ch) in text.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) {
                    displayed.append(ch)
                }
            }
        }
    }
}

// MARK: - Status Row (openCODE style)

struct StatusRow: View {
    let label: String
    let status: Status
    let message: String

    enum Status: Equatable {
        case pending
        case running
        case pass
        case warning
        case fail

        var tint: Color {
            switch self {
            case .pending: return .secondary
            case .running: return .blue
            case .pass:    return .green
            case .warning: return .orange
            case .fail:    return .red
            }
        }

        var icon: String {
            switch self {
            case .pending: return "circle.dotted"
            case .running: return "circle.dashed"
            case .pass:    return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .fail:    return "xmark.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if status == .running {
                BouncingDots(color: .blue)
                    .frame(width: 20)
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(status.tint)
                    .frame(width: 20)
            }

            Text(label)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(status == .pending ? .secondary : .primary)

            Spacer()

            if !message.isEmpty {
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor).opacity(status == .running ? 1 : 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(status == .running ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Splash Logo Animation

struct SplashLogo: View {
    @State private var pulse = false
    @State private var dots = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .scaleEffect(pulse ? 1.05 : 0.95)
                .opacity(pulse ? 1 : 0.7)

            Text("PaglaMLX")
                .font(.system(.title, design: .monospaced).bold())
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                )

            HStack(spacing: 0) {
                Text("booting")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Text(dots)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .leading)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { t in
                dots = dots.count >= 3 ? "" : dots + "."
            }
        }
    }
}

// MARK: - Progress Bar (openCODE style)

struct OpenCodeProgress: View {
    let progress: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.easeOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 4)
    }
}
