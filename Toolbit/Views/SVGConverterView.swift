import SwiftUI
import AppKit

struct SVGConverterView: View {
    @State private var svgText: String = ""
    @State private var convertedImage: NSImage?
    @State private var errorMessage: String?
    @State private var isDropTargeted: Bool = false
    @State private var hasInitialized: Bool = false
    @State private var isProcessing: Bool = false
    @State private var outputScale: Double = 2.0
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HStack(spacing: 20) {
                // 左侧：SVG 代码区域
                svgPanel
                
                // 右侧：图片预览区域
                imagePanel
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                checkPasteboardOnAppear()
            }
        }
        .onChange(of: svgText) { _, _ in
            triggerDebouncedConvert()
        }
        .onChange(of: outputScale) { _, _ in
            if !svgText.isEmpty {
                convertSVGToImage()
            }
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SVG 转图片")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("将 SVG 代码转换为 PNG 图片")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 缩放倍数选择
            HStack(spacing: 8) {
                Text("输出倍率:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $outputScale) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("3x").tag(3.0)
                    Text("4x").tag(4.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.horizontal, 8)
            }
            
            Button(action: clearAll) {
                Label("全部清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(svgText.isEmpty && convertedImage == nil)
        }
        .padding()
    }
    
    // MARK: - SVG 面板
    private var svgPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SVG 代码")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    if !svgText.isEmpty {
                        Text("\(svgText.count) 字符")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: pasteSVG) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: selectSVGFile) {
                        Label("选择", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !svgText.isEmpty {
                        Button(action: copySVG) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { svgText = "" }) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // SVG 代码输入区
            ZStack(alignment: .topLeading) {
                TextEditor(text: $svgText)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                
                if svgText.isEmpty {
                    Text("粘贴或输入 SVG 代码，自动转换为图片...\n\n示例:\n<svg width=\"100\" height=\"100\">\n  <circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"blue\"/>\n</svg>")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .frame(minWidth: 350)
    }
    
    // MARK: - 图片面板
    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("图片预览")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    if convertedImage != nil {
                        Button(action: copyImage) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: saveImage) {
                            Label("保存", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { convertedImage = nil }) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // 图片显示区域
            ZStack {
                // 透明背景网格
                CheckerboardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                
                if let image = convertedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text("输入 SVG 代码后自动生成图片")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 图片信息
            if let image = convertedImage {
                imageInfoView(image: image)
            }
            
            // 错误信息
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.1))
                }
            }
        }
        .frame(minWidth: 350)
    }
    
    private func imageInfoView(image: NSImage) -> some View {
        HStack(spacing: 16) {
            Label("\(Int(image.size.width)) x \(Int(image.size.height))", systemImage: "aspectratio")
            Label("\(outputScale, specifier: "%.0f")x 倍率", systemImage: "magnifyingglass")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedConvert() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    convertSVGToImage()
                }
            }
        }
    }
    
    private func convertSVGToImage() {
        guard !svgText.isEmpty else {
            convertedImage = nil
            errorMessage = nil
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 解析 SVG 获取尺寸
            let (width, height) = parseSVGDimensions(svgText)
            
            let scaledWidth = width * outputScale
            let scaledHeight = height * outputScale
            
            // 使用 NSImage 的 SVG 渲染能力
            guard let svgData = svgText.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法解析 SVG 代码"
                    self.isProcessing = false
                }
                return
            }
            
            // 尝试使用 NSImage 直接加载 SVG
            if let svgImage = NSImage(data: svgData) {
                // 创建指定尺寸的图片
                let targetSize = NSSize(width: scaledWidth, height: scaledHeight)
                let resultImage = NSImage(size: targetSize)
                
                resultImage.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                svgImage.draw(in: NSRect(origin: .zero, size: targetSize),
                             from: NSRect(origin: .zero, size: svgImage.size),
                             operation: .copy,
                             fraction: 1.0)
                resultImage.unlockFocus()
                
                DispatchQueue.main.async {
                    self.convertedImage = resultImage
                    self.errorMessage = nil
                    self.isProcessing = false
                }
            } else {
                // 备用方案：使用 WebView 渲染（简化版，直接报错）
                DispatchQueue.main.async {
                    self.errorMessage = "无法渲染 SVG，请检查代码是否正确"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func parseSVGDimensions(_ svg: String) -> (Double, Double) {
        // 尝试从 SVG 标签中提取 width 和 height
        var width: Double = 200
        var height: Double = 200
        
        // 匹配 width="xxx" 或 width='xxx'
        if let widthMatch = svg.range(of: #"width\s*=\s*["']?(\d+)"#, options: .regularExpression) {
            let widthStr = svg[widthMatch]
            if let numMatch = widthStr.range(of: #"\d+"#, options: .regularExpression) {
                width = Double(widthStr[numMatch]) ?? 200
            }
        }
        
        // 匹配 height="xxx" 或 height='xxx'
        if let heightMatch = svg.range(of: #"height\s*=\s*["']?(\d+)"#, options: .regularExpression) {
            let heightStr = svg[heightMatch]
            if let numMatch = heightStr.range(of: #"\d+"#, options: .regularExpression) {
                height = Double(heightStr[numMatch]) ?? 200
            }
        }
        
        // 尝试从 viewBox 获取尺寸
        if let viewBoxMatch = svg.range(of: #"viewBox\s*=\s*["']([^"']+)["']"#, options: .regularExpression) {
            let viewBoxStr = String(svg[viewBoxMatch])
            let numbers = viewBoxStr.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                .compactMap { Double($0) }
            if numbers.count >= 4 {
                if width == 200 { width = numbers[2] }
                if height == 200 { height = numbers[3] }
            }
        }
        
        return (max(width, 10), max(height, 10))
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("<svg") && trimmed.contains("</svg>") {
                svgText = trimmed
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // 尝试加载文件 URL
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                if url.pathExtension.lowercased() == "svg" {
                    if let svgContent = try? String(contentsOf: url, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.svgText = svgContent
                        }
                    }
                }
            }
            
            // 尝试加载文本
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    if text.contains("<svg") {
                        DispatchQueue.main.async {
                            self.svgText = text
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - SVG 操作
    
    private func pasteSVG() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            svgText = string
        }
    }
    
    private func copySVG() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(svgText, forType: .string)
    }
    
    private func selectSVGFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择 SVG 文件"
        panel.prompt = "选择"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            
            if let svgContent = try? String(contentsOf: url, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.svgText = svgContent
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法读取 SVG 文件"
                }
            }
        }
    }
    
    // MARK: - 图片操作
    
    private func copyImage() {
        guard let image = convertedImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func saveImage() {
        guard let image = convertedImage,
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "image.png"
        panel.message = "保存图片"
        panel.prompt = "保存"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            try? pngData.write(to: url)
        }
    }
    
    private func clearAll() {
        svgText = ""
        convertedImage = nil
        errorMessage = nil
    }
}

// MARK: - 透明背景网格
struct CheckerboardBackground: View {
    let gridSize: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            let columns = Int(ceil(geometry.size.width / gridSize))
            let rows = Int(ceil(geometry.size.height / gridSize))
            
            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let isLight = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * gridSize,
                            y: CGFloat(row) * gridSize,
                            width: gridSize,
                            height: gridSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isLight ? Color.white : Color.gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    SVGConverterView()
        .frame(width: 900, height: 600)
}
