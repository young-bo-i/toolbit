import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct Base64ImageView: View {
    @State private var base64Text: String = ""
    @State private var currentImage: NSImage?
    @State private var errorMessage: String?
    @State private var isDropTargeted: Bool = false
    @State private var hasInitialized: Bool = false
    @State private var isProcessing: Bool = false
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    // 支持的图片格式前缀
    private let base64Prefixes = [
        "data:image/png;base64,",
        "data:image/jpeg;base64,",
        "data:image/jpg;base64,",
        "data:image/gif;base64,",
        "data:image/webp;base64,",
        "data:image/bmp;base64,",
        "data:image/svg+xml;base64,"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HStack(spacing: 20) {
                // 左侧：图片区域
                imagePanel
                
                // 右侧：Base64 文本区域
                base64Panel
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
        .onDisappear {
            // 切换页面时清空状态
            debounceTask?.cancel()
            debounceTask = nil
            base64Text = ""
            currentImage = nil
            errorMessage = nil
            hasInitialized = false
        }
        // 全局粘贴快捷键 ⌘+V
        .onPasteCommand(of: [.image, .png, .jpeg, .gif, .bmp, .fileURL, .plainText]) { providers in
            handlePaste(providers: providers)
        }
        // 备用：使用 keyboardShortcut 监听
        .background {
            Button("") {
                handleGlobalPaste()
            }
            .keyboardShortcut("v", modifiers: .command)
            .opacity(0)
        }
    }
    
    // MARK: - 全局粘贴处理
    private func handleGlobalPaste() {
        let pasteboard = NSPasteboard.general
        
        // 优先检查图片
        if let image = NSImage(pasteboard: pasteboard) {
            setImage(image)
            return
        }
        
        // 检查文件 URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            setImage(image)
            return
        }
        
        // 检查文本（可能是 Base64）
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                setBase64(trimmed)
            }
        }
    }
    
    private func handlePaste(providers: [NSItemProvider]) {
        for provider in providers {
            // 尝试加载图片
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        DispatchQueue.main.async {
                            self.setImage(nsImage)
                        }
                    }
                }
                return
            }
            
            // 尝试加载字符串
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.setBase64(string.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } else if let string = item as? String {
                    DispatchQueue.main.async {
                        self.setBase64(string.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base64 图片")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("图片与 Base64 编码自动互转，支持拖拽和粘贴")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }
            
            Button(action: clearAll) {
                Label("全部清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(base64Text.isEmpty && currentImage == nil)
        }
        .padding()
    }
    
    // MARK: - 图片面板
    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("图片预览")
                    .font(.headline)
                Spacer()
                
                // 图片操作按钮
                HStack(spacing: 8) {
                    Button(action: pasteImage) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: selectImageFile) {
                        Label("选择", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if currentImage != nil {
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
                        
                        Button(action: clearImage) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // 图片显示/拖拽区域
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isDropTargeted ? Color.blue : Color.gray.opacity(0.3),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 2, dash: currentImage == nil ? [8] : [])
                            )
                    }
                
                if let image = currentImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text("拖拽图片到此处")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("或点击上方按钮选择/粘贴图片")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Text("支持 PNG、JPEG、GIF、WebP 等格式")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // 图片信息
            if let image = currentImage {
                imageInfoView(image: image)
            }
        }
        .frame(minWidth: 350)
    }
    
    // MARK: - Base64 面板
    private var base64Panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Base64 编码")
                    .font(.headline)
                
                Spacer()
                
                // Base64 操作按钮
                HStack(spacing: 8) {
                    Button(action: pasteBase64) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !base64Text.isEmpty {
                        Text("\(formatCharCount(base64Text.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.ultraThinMaterial))
                        
                        Button(action: copyBase64) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: saveBase64) {
                            Label("保存", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: clearBase64) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // Base64 文本显示区域 - 使用 ScrollView + Text 替代 TextEditor 提升性能
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                if base64Text.isEmpty {
                    Text("粘贴 Base64 编码，将自动解码为图片...")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                } else {
                    ScrollView {
                        Text(base64Text)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
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
    
    // MARK: - 图片信息视图
    private func imageInfoView(image: NSImage) -> some View {
        HStack(spacing: 16) {
            Label("\(Int(image.size.width)) x \(Int(image.size.height))", systemImage: "aspectratio")
            
            if let tiffData = image.tiffRepresentation {
                Label(formatFileSize(tiffData.count), systemImage: "doc")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        }
    }
    
    // MARK: - 图片操作方法
    
    private func pasteImage() {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            setImage(image)
        }
    }
    
    private func copyImage() {
        guard let image = currentImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func saveImage() {
        guard let image = currentImage,
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
    
    private func clearImage() {
        currentImage = nil
        // 不清空 base64，让用户可以保留
    }
    
    // MARK: - Base64 操作方法
    
    private func pasteBase64() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            setBase64(trimmed)
        }
    }
    
    private func copyBase64() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(base64Text, forType: .string)
    }
    
    private func saveBase64() {
        let textToSave = base64Text
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "base64.txt"
        panel.message = "保存 Base64 编码"
        panel.prompt = "保存"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            try? textToSave.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func clearBase64() {
        base64Text = ""
        errorMessage = nil
        // 不清空图片，让用户可以保留
    }
    
    // MARK: - 自动同步方法
    
    /// 设置图片并自动编码为 Base64
    private func setImage(_ image: NSImage) {
        currentImage = image
        errorMessage = nil
        
        // 自动编码
        encodeImageToBase64()
    }
    
    /// 设置 Base64 并自动解码为图片
    private func setBase64(_ text: String) {
        base64Text = text
        errorMessage = nil
        
        // 使用防抖延迟解码
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if !Task.isCancelled {
                await MainActor.run {
                    decodeBase64ToImage()
                }
            }
        }
    }
    
    /// 初次进入时检查粘贴板
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        
        // 先检查是否有图片
        if let image = NSImage(pasteboard: pasteboard) {
            setImage(image)
            return
        }
        
        // 再检查是否有文本（可能是 Base64）
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidBase64Image(trimmed) {
                setBase64(trimmed)
            }
        }
    }
    
    /// 检查是否是有效的 Base64 图片编码
    private func isValidBase64Image(_ text: String) -> Bool {
        for prefix in base64Prefixes {
            if text.hasPrefix(prefix) {
                return true
            }
        }
        
        if text.count > 100 {
            let cleanBase64 = text
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: " ", with: "")
            
            if let data = Data(base64Encoded: cleanBase64),
               NSImage(data: data) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// 处理拖拽
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, error in
                    DispatchQueue.main.async {
                        if let nsImage = image as? NSImage {
                            self.setImage(nsImage)
                        }
                    }
                }
                return
            }
            
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.setImage(image)
                }
            }
        }
    }
    
    /// 选择图片文件
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择图片文件"
        panel.prompt = "选择"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            
            if let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    self.setImage(image)
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法加载图片文件"
                }
            }
        }
    }
    
    /// 图片编码为 Base64
    private func encodeImageToBase64() {
        guard let image = currentImage else { return }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let tiffData = image.tiffRepresentation,
                  let bitmapRep = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                DispatchQueue.main.async {
                    self.errorMessage = "图片编码失败"
                    self.isProcessing = false
                }
                return
            }
            
            let base64String = pngData.base64EncodedString()
            let result = "data:image/png;base64," + base64String
            
            DispatchQueue.main.async {
                self.base64Text = result
                self.errorMessage = nil
                self.isProcessing = false
            }
        }
    }
    
    /// Base64 解码为图片
    private func decodeBase64ToImage() {
        let base64String = base64Text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if base64String.isEmpty {
            return
        }
        
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 移除可能的前缀
            var cleanString = base64String
            for prefix in self.base64Prefixes {
                if cleanString.hasPrefix(prefix) {
                    cleanString = String(cleanString.dropFirst(prefix.count))
                    break
                }
            }
            
            // 清理换行和空格
            cleanString = cleanString
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: " ", with: "")
            
            guard let imageData = Data(base64Encoded: cleanString) else {
                DispatchQueue.main.async {
                    self.errorMessage = "无效的 Base64 编码"
                    self.isProcessing = false
                }
                return
            }
            
            guard let image = NSImage(data: imageData) else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法解析为图片"
                    self.isProcessing = false
                }
                return
            }
            
            DispatchQueue.main.async {
                self.currentImage = image
                self.errorMessage = nil
                self.isProcessing = false
            }
        }
    }
    
    /// 清空所有
    private func clearAll() {
        base64Text = ""
        currentImage = nil
        errorMessage = nil
    }
    
    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// 格式化字符数
    private func formatCharCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}

#Preview {
    Base64ImageView()
        .frame(width: 900, height: 600)
}
