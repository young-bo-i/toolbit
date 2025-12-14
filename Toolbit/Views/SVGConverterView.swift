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
            // 页面标题
            PageHeader(
                title: ToolType.svgConverter.displayName,
                subtitle: ToolType.svgConverter.subtitle,
                icon: ToolType.svgConverter.icon,
                color: ToolType.svgConverter.color
            )
            
            HStack(spacing: 16) {
                // 左侧：SVG 代码
                svgPanel
                
                // 右侧：图片预览
                imagePanel
            }
            .padding(20)
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                checkPasteboardOnAppear()
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            svgText = ""
            convertedImage = nil
            errorMessage = nil
            hasInitialized = false
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
    
    // MARK: - SVG 面板
    private var svgPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Text("SVG 代码")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(svgText.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                
                HStack(spacing: 2) {
                    GlassToolButton(icon: "doc.on.clipboard", action: pasteSVG, help: "粘贴")
                    GlassToolButton(icon: "folder", action: selectSVGFile, help: "选择文件")
                    GlassToolButton(icon: "doc.on.doc", action: copySVG, isDisabled: svgText.isEmpty, help: "复制")
                    GlassToolButton(icon: "xmark.circle", action: { svgText = "" }, isDisabled: svgText.isEmpty, help: "清空")
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // SVG 代码编辑区
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $svgText)
                
                if svgText.isEmpty {
                    Text("粘贴或输入 SVG 代码...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isDropTargeted ? 2 : 0.5)
        }
    }
    
    // MARK: - 图片面板
    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "photo")
                    .foregroundStyle(.purple)
                Text("图片预览")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 缩放倍数
                HStack(spacing: 4) {
                    Text("倍率")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $outputScale) {
                        Text("1x").tag(1.0)
                        Text("2x").tag(2.0)
                        Text("3x").tag(3.0)
                        Text("4x").tag(4.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 6)
                
                HStack(spacing: 4) {
                    Button(action: copyImage) {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(convertedImage == nil)
                    .help("复制")
                    
                    Button(action: saveImage) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(convertedImage == nil)
                    .help("保存")
                    
                    Button(action: { convertedImage = nil }) {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(convertedImage == nil)
                    .help("清空")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 图片显示区
            ZStack {
                // 透明背景网格
                CheckerboardBackground()
                
                if let image = convertedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.artframe")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        
                        Text("输入 SVG 代码后自动生成图片")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 图片信息 & 错误信息
            if let image = convertedImage {
                HStack(spacing: 16) {
                    Label("\(Int(image.size.width)) × \(Int(image.size.height))", systemImage: "aspectratio")
                    Label("\(outputScale, specifier: "%.0f")x", systemImage: "magnifyingglass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
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
                // 创建指定尺寸的位图
                let targetSize = NSSize(width: scaledWidth, height: scaledHeight)
                
                // 使用 NSBitmapImageRep 创建精确尺寸的位图
                guard let bitmapRep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: Int(scaledWidth),
                    pixelsHigh: Int(scaledHeight),
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ) else {
                    DispatchQueue.main.async {
                        self.errorMessage = "无法创建图片缓冲区"
                        self.isProcessing = false
                    }
                    return
                }
                
                // 设置位图尺寸（用于渲染）
                bitmapRep.size = targetSize
                
                // 在位图上下文中绘制 SVG
                NSGraphicsContext.saveGraphicsState()
                let context = NSGraphicsContext(bitmapImageRep: bitmapRep)
                NSGraphicsContext.current = context
                context?.imageInterpolation = .high
                
                // 计算绘制区域，保持原始 SVG 的宽高比
                let svgAspect = svgImage.size.width / svgImage.size.height
                let targetAspect = scaledWidth / scaledHeight
                
                var drawRect = NSRect(origin: .zero, size: targetSize)
                
                if svgAspect > targetAspect {
                    // SVG 更宽，以宽度为准
                    let newHeight = scaledWidth / svgAspect
                    drawRect.origin.y = (scaledHeight - newHeight) / 2
                    drawRect.size.height = newHeight
                } else {
                    // SVG 更高，以高度为准
                    let newWidth = scaledHeight * svgAspect
                    drawRect.origin.x = (scaledWidth - newWidth) / 2
                    drawRect.size.width = newWidth
                }
                
                // 绘制 SVG（使用原始尺寸作为源区域）
                svgImage.draw(
                    in: drawRect,
                    from: NSRect(origin: .zero, size: svgImage.size),
                    operation: .copy,
                    fraction: 1.0
                )
                
                NSGraphicsContext.restoreGraphicsState()
                
                // 创建最终图片
                let resultImage = NSImage(size: targetSize)
                resultImage.addRepresentation(bitmapRep)
                
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
        var width: Double? = nil
        var height: Double? = nil
        var viewBoxWidth: Double? = nil
        var viewBoxHeight: Double? = nil
        
        // 提取数值（支持带单位如 px, pt, em 等）
        func extractNumber(from str: String) -> Double? {
            let pattern = #"([\d.]+)"#
            if let range = str.range(of: pattern, options: .regularExpression) {
                return Double(str[range])
            }
            return nil
        }
        
        // 匹配 width="xxx" 或 width='xxx'（支持带单位）
        let widthPattern = #"<svg[^>]*\swidth\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: widthPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: svg, options: [], range: NSRange(svg.startIndex..., in: svg)),
           let range = Range(match.range(at: 1), in: svg) {
            let value = String(svg[range])
            // 如果是百分比，跳过
            if !value.contains("%") {
                width = extractNumber(from: value)
            }
        }
        
        // 匹配 height="xxx" 或 height='xxx'（支持带单位）
        let heightPattern = #"<svg[^>]*\sheight\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: heightPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: svg, options: [], range: NSRange(svg.startIndex..., in: svg)),
           let range = Range(match.range(at: 1), in: svg) {
            let value = String(svg[range])
            // 如果是百分比，跳过
            if !value.contains("%") {
                height = extractNumber(from: value)
            }
        }
        
        // 解析 viewBox（格式: "minX minY width height"）
        let viewBoxPattern = #"<svg[^>]*\sviewBox\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: viewBoxPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: svg, options: [], range: NSRange(svg.startIndex..., in: svg)),
           let range = Range(match.range(at: 1), in: svg) {
            let viewBoxStr = String(svg[range])
            // viewBox 值用空格或逗号分隔
            let components = viewBoxStr.components(separatedBy: CharacterSet(charactersIn: " ,"))
                .filter { !$0.isEmpty }
                .compactMap { Double($0) }
            if components.count >= 4 {
                viewBoxWidth = components[2]
                viewBoxHeight = components[3]
            }
        }
        
        // 优先使用 width/height，如果没有则用 viewBox
        let finalWidth = width ?? viewBoxWidth ?? 200
        let finalHeight = height ?? viewBoxHeight ?? 200
        
        return (max(finalWidth, 10), max(finalHeight, 10))
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
