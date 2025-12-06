import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    @State private var inputText: String = ""
    @State private var qrCodeImage: NSImage?
    @State private var decodedText: String = ""
    @State private var errorMessage: String?
    @State private var isDropTargeted: Bool = false
    @State private var hasInitialized: Bool = false
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HStack(spacing: 20) {
                // 左侧：文本输入区域
                textPanel
                
                // 右侧：二维码区域
                qrCodePanel
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
        .onChange(of: inputText) { _, _ in
            triggerDebouncedEncode()
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("二维码工具")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("文本生成二维码，或识别二维码内容")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: clearAll) {
                Label("全部清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(inputText.isEmpty && qrCodeImage == nil)
        }
        .padding()
    }
    
    // MARK: - 文本面板
    private var textPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("文本内容")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    if !inputText.isEmpty {
                        Text("\(inputText.count) 字符")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button(action: pasteText) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !inputText.isEmpty {
                        Button(action: copyText) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { inputText = "" }) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            // 文本输入区
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                
                if inputText.isEmpty {
                    Text("输入文本自动生成二维码...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 解码结果显示
            if !decodedText.isEmpty && decodedText != inputText {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("识别结果")
                            .font(.headline)
                        Spacer()
                        Button(action: { 
                            inputText = decodedText 
                        }) {
                            Label("使用此内容", systemImage: "arrow.up.square")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { copyToClipboard(decodedText) }) {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    ScrollView {
                        Text(decodedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(height: 100)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        }
        .frame(minWidth: 350)
    }
    
    // MARK: - 二维码面板
    private var qrCodePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("二维码")
                    .font(.headline)
                Spacer()
                
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
                    
                    if qrCodeImage != nil {
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
            
            // 二维码显示/拖拽区域
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isDropTargeted ? Color.blue : Color.gray.opacity(0.3),
                                style: StrokeStyle(lineWidth: isDropTargeted ? 3 : 2, dash: qrCodeImage == nil ? [8] : [])
                            )
                    }
                
                if let image = qrCodeImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text("输入文本生成二维码")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("或拖拽/粘贴二维码图片进行识别")
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
    
    // MARK: - 操作方法
    
    private func triggerDebouncedEncode() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    generateQRCode()
                }
            }
        }
    }
    
    private func generateQRCode() {
        guard !inputText.isEmpty else {
            qrCodeImage = nil
            return
        }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(inputText.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else {
            errorMessage = "无法生成二维码"
            return
        }
        
        // 放大二维码以获得清晰的图像
        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            errorMessage = "无法生成二维码图像"
            return
        }
        
        qrCodeImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        errorMessage = nil
    }
    
    private func decodeQRCode(from image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            errorMessage = "无法读取图片"
            return
        }
        
        let context = CIContext()
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        
        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature],
              let firstFeature = features.first,
              let messageString = firstFeature.messageString else {
            errorMessage = "未识别到二维码"
            decodedText = ""
            return
        }
        
        decodedText = messageString
        errorMessage = nil
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        
        // 先检查是否有图片
        if let image = NSImage(pasteboard: pasteboard) {
            qrCodeImage = image
            decodeQRCode(from: image)
            return
        }
        
        // 再检查是否有文本
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 5000 {
                inputText = trimmed
            }
        }
    }
    
    // MARK: - 文本操作
    
    private func pasteText() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            inputText = string
        }
    }
    
    private func copyText() {
        copyToClipboard(inputText)
    }
    
    // MARK: - 图片操作
    
    private func pasteImage() {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            qrCodeImage = image
            decodeQRCode(from: image)
        }
    }
    
    private func copyImage() {
        guard let image = qrCodeImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
    
    private func saveImage() {
        guard let image = qrCodeImage,
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "qrcode.png"
        panel.message = "保存二维码"
        panel.prompt = "保存"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            try? pngData.write(to: url)
        }
    }
    
    private func clearImage() {
        qrCodeImage = nil
        decodedText = ""
        errorMessage = nil
    }
    
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "选择二维码图片"
        panel.prompt = "选择"
        
        panel.begin { [weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            
            if let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    self.qrCodeImage = image
                    self.decodeQRCode(from: image)
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "无法加载图片文件"
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { image, _ in
                    if let nsImage = image as? NSImage {
                        DispatchQueue.main.async {
                            self.qrCodeImage = nsImage
                            self.decodeQRCode(from: nsImage)
                        }
                    }
                }
                return
            }
            
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let image = NSImage(contentsOf: url) else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.qrCodeImage = image
                    self.decodeQRCode(from: image)
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func clearAll() {
        inputText = ""
        qrCodeImage = nil
        decodedText = ""
        errorMessage = nil
    }
}

#Preview {
    QRCodeView()
        .frame(width: 900, height: 600)
}
