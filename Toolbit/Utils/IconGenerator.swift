import SwiftUI
import AppKit

/// 图标生成器 - 用于生成 App Icon 的各种尺寸
struct IconGenerator {
    
    /// 生成所有尺寸的 App Icon 并保存到指定目录
    @MainActor
    static func generateAllIcons(to directory: URL) {
        let sizes: [(name: String, size: CGFloat)] = [
            ("icon_16x16", 16),
            ("icon_16x16@2x", 32),
            ("icon_32x32", 32),
            ("icon_32x32@2x", 64),
            ("icon_128x128", 128),
            ("icon_128x128@2x", 256),
            ("icon_256x256", 256),
            ("icon_256x256@2x", 512),
            ("icon_512x512", 512),
            ("icon_512x512@2x", 1024)
        ]
        
        for (name, size) in sizes {
            if let image = renderIcon(size: size) {
                let url = directory.appendingPathComponent("\(name).png")
                saveImage(image, to: url)
                print("Generated: \(name).png")
            }
        }
    }
    
    /// 渲染指定尺寸的图标
    @MainActor
    static func renderIcon(size: CGFloat) -> NSImage? {
        let view = IconRenderView(size: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
    
    /// 保存图片到文件
    static func saveImage(_ image: NSImage, to url: URL) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        
        try? pngData.write(to: url)
    }
}

/// 用于渲染图标的视图（无圆角，用于 App Icon）
/// 颜色与 AppLogoView 保持一致
private struct IconRenderView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 渐变背景 - 深蓝到紫红的渐变 (与 AppLogoView 一致)
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.25, blue: 0.5),   // 深蓝
                    Color(red: 0.45, green: 0.2, blue: 0.5),    // 紫色
                    Color(red: 0.7, green: 0.25, blue: 0.4)     // 玫红
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 图标
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// 开发时用于生成图标的视图
struct IconGeneratorView: View {
    @State private var isGenerating = false
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("App Icon 生成器")
                .font(.title)
            
            // 预览
            AppLogoView(size: 128)
            
            Button(action: generateIcons) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("生成图标到桌面")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGenerating)
            
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(width: 300, height: 300)
    }
    
    @MainActor
    private func generateIcons() {
        isGenerating = true
        message = "正在生成..."
        
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let iconDir = desktop.appendingPathComponent("ToolbitIcons")
        
        try? FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)
        
        IconGenerator.generateAllIcons(to: iconDir)
        
        message = "图标已生成到桌面 ToolbitIcons 文件夹"
        isGenerating = false
    }
}

#Preview {
    IconGeneratorView()
}

