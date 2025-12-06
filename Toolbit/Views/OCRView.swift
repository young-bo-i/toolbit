import SwiftUI
import AppKit
import Vision
import UniformTypeIdentifiers

struct OCRView: View {
    @State private var selectedImage: NSImage?
    @State private var recognizedText: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    @State private var recognitionLanguages: [String] = ["zh-Hans", "zh-Hant", "en-US"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HSplitView {
                // 左侧：图片区域
                imagePanel
                    .frame(minWidth: 350)
                
                // 右侧：识别结果
                resultPanel
                    .frame(minWidth: 350)
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
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("OCR 文字识别")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("从图片中识别并提取文字")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 识别精度选择
            HStack(spacing: 8) {
                Text("精度:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $recognitionLevel) {
                    Text("快速").tag(VNRequestTextRecognitionLevel.fast)
                    Text("精确").tag(VNRequestTextRecognitionLevel.accurate)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
            
            Button(action: clearAll) {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(selectedImage == nil && recognizedText.isEmpty)
        }
        .padding()
    }
    
    // MARK: - 图片面板
    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("图片")
                    .font(.headline)
                Spacer()
                
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
                
                if selectedImage != nil {
                    Button(action: { selectedImage = nil; recognizedText = ""; errorMessage = nil }) {
                        Label("清空", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // 图片显示/拖放区域
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                if let image = selectedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("拖放图片到这里")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("或点击「选择」按钮选择图片")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("支持 PNG、JPG、JPEG、GIF、BMP、TIFF")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if isProcessing {
                    Color.black.opacity(0.3)
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // 识别按钮
            if selectedImage != nil && !isProcessing {
                Button(action: performOCR) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                        Text("开始识别")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
    
    // MARK: - 结果面板
    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("识别结果")
                    .font(.headline)
                Spacer()
                
                if !recognizedText.isEmpty {
                    Text("\(recognizedText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: copyResult) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(action: saveResult) {
                        Label("保存", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recognizedText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("识别结果将显示在这里")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        if selectedImage != nil {
                            Text("点击「开始识别」按钮进行 OCR 识别")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(recognizedText)
                            .font(.system(.body, design: .default))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 操作方法
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        
        // 检查是否有图片
        if let image = NSImage(pasteboard: pasteboard) {
            selectedImage = image
        }
    }
    
    private func pasteImage() {
        let pasteboard = NSPasteboard.general
        
        if let image = NSImage(pasteboard: pasteboard) {
            selectedImage = image
            recognizedText = ""
            errorMessage = nil
        }
    }
    
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.selectedImage = image
                        self.recognizedText = ""
                        self.errorMessage = nil
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            // 尝试加载图片
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let data = data, let image = NSImage(data: data) {
                        DispatchQueue.main.async {
                            self.selectedImage = image
                            self.recognizedText = ""
                            self.errorMessage = nil
                        }
                    }
                }
                return
            }
            
            // 尝试加载文件 URL
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil),
                       let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            self.selectedImage = image
                            self.recognizedText = ""
                            self.errorMessage = nil
                        }
                    }
                }
                return
            }
        }
    }
    
    private func performOCR() {
        guard let image = selectedImage,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "无法处理图片"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        recognizedText = ""
        
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { request, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    if let error = error {
                        self.errorMessage = "识别失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        self.errorMessage = "无法获取识别结果"
                        return
                    }
                    
                    if observations.isEmpty {
                        self.errorMessage = "未识别到任何文字"
                        return
                    }
                    
                    // 提取识别的文字
                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    self.recognizedText = recognizedStrings.joined(separator: "\n")
                }
            }
            
            // 配置识别请求
            request.recognitionLevel = self.recognitionLevel
            request.recognitionLanguages = self.recognitionLanguages
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "识别失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func copyResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(recognizedText, forType: .string)
    }
    
    private func saveResult() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "ocr_result.txt"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? self.recognizedText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func clearAll() {
        selectedImage = nil
        recognizedText = ""
        errorMessage = nil
    }
}

#Preview {
    OCRView()
        .frame(width: 1000, height: 700)
}
