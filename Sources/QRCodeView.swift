import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: String
    
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
                    Text("export OPENAI_BASE_URL=\(url)/v1")
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("export OPENAI_BASE_URL=\(url)/v1", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                }
                
                Text("2. Health Check (curl)")
                    .font(.headline)
                    .padding(.top, 4)
                
                HStack {
                    Text("curl \(url)/v1/models")
                        .font(.system(.subheadline, design: .monospaced))
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("curl \(url)/v1/models", forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
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
