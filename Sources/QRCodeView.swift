import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: String
    @State private var copiedCommand: String?
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Connect from Termux")
                .font(.title2)
                .bold()
            
            if let image = generateQRCode(from: url) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            } else {
                Text("Failed to generate QR code")
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("1. Set Environment Variable")
                    .font(.headline)
                
                HStack {
                    let exportCommand = "export OPENAI_BASE_URL=\(url)/v1"
                    Text(exportCommand)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button(action: { copy(exportCommand) }) {
                        Image(systemName: copiedCommand == exportCommand ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel("Copy environment variable command")
                    .help(copiedCommand == exportCommand ? "Copied" : "Copy command")
                    .buttonStyle(.plain)
                }
                
                Text("2. Health Check (curl)")
                    .font(.headline)
                    .padding(.top, 4)
                
                HStack {
                    let healthCheckCommand = "curl \(url)/v1/models"
                    Text(healthCheckCommand)
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button(action: { copy(healthCheckCommand) }) {
                        Image(systemName: copiedCommand == healthCheckCommand ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel("Copy health check command")
                    .help(copiedCommand == healthCheckCommand ? "Copied" : "Copy command")
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(30)
        .frame(width: 450)
    }
    
    private func copy(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copiedCommand = command
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if copiedCommand == command {
                copiedCommand = nil
            }
        }
    }
    
    private func generateQRCode(from string: String) -> NSImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            // Scale up the image to prevent blurriness
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
        return nil
    }
}
