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
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：文本输入
            textPanel
            
            // 右侧：二维码
            qrCodePanel
        }
        .padding(20)
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                checkPasteboardOnAppear()
            }
        }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            inputText = ""
            qrCodeImage = nil
            decodedText = ""
            errorMessage = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in
            triggerDebouncedEncode()
        }
    }
    
    // MARK: - 文本面板
    private var textPanel: some View {
        VStack(spacing: 0) {
            // 输入区
            VStack(alignment: .leading, spacing: 0) {
                // 标题栏
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.blue)
                    Text("文本内容")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(inputText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    
                    Divider()
                        .frame(height: 12)
                        .padding(.horizontal, 6)
                    
                    HStack(spacing: 4) {
                        Button(action: pasteText) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .help("粘贴")
                        
                        Button(action: copyText) {
                            Image(systemName: "doc.on.doc")
                        }
                        .disabled(inputText.isEmpty)
                        .help("复制")
                        
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle")
                        }
                        .disabled(inputText.isEmpty)
                        .help("清空")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
                
                // 文本输入
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                    
                    if inputText.isEmpty {
                        Text("输入文本自动生成二维码...")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            
            // 识别结果（如果有）
            if !decodedText.isEmpty && decodedText != inputText {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题栏
                    HStack {
                        Image(systemName: "text.viewfinder")
                            .foregroundStyle(.green)
                        Text("识别结果")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Button(action: { inputText = decodedText }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.square")
                                    Text("使用")
                                }
                                .font(.caption)
                            }
                            .help("使用此内容生成新二维码")
                            
                            Button(action: { copyToClipboard(decodedText) }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .help("复制")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .windowBackgroundColor))
                    
                    ScrollView {
                        Text(decodedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(height: 100)
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                }
                .padding(.top, 12)
            }
        }
    }
    
    // MARK: - 二维码面板
    private var qrCodePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "qrcode")
                    .foregroundStyle(.purple)
                Text("二维码")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: pasteImage) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("粘贴图片")
                    
                    Button(action: selectImageFile) {
                        Image(systemName: "folder")
                    }
                    .help("选择图片")
                    
                    Button(action: copyImage) {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(qrCodeImage == nil)
                    .help("复制")
                    
                    Button(action: saveImage) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(qrCodeImage == nil)
                    .help("保存")
                    
                    Button(action: clearImage) {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(qrCodeImage == nil)
                    .help("清空")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 二维码显示区
            ZStack {
                if let image = qrCodeImage {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .padding(32)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        
                        Text("输入文本生成二维码")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("或拖拽 / 粘贴二维码图片进行识别")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // 拖拽状态边框
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // 错误信息
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
