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
    
    @State private var isDropTargeted: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：图片
            imagePanel
            
            // 右侧：识别结果
            resultPanel
        }
        .padding(20)
        .onAppear {
            if !hasInitialized {
                hasInitialized = true
                checkPasteboardOnAppear()
            }
        }
        .onDisappear {
            selectedImage = nil
            recognizedText = ""
            errorMessage = nil
            hasInitialized = false
        }
    }
    
    // MARK: - 图片面板
    private var imagePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "photo")
                    .foregroundStyle(.blue)
                Text("图片")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // 识别精度
                HStack(spacing: 4) {
                    Text("精度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $recognitionLevel) {
                        Text("快速").tag(VNRequestTextRecognitionLevel.fast)
                        Text("精确").tag(VNRequestTextRecognitionLevel.accurate)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 6)
                
                HStack(spacing: 4) {
                    Button(action: pasteImage) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("粘贴图片")
                    
                    Button(action: selectImageFile) {
                        Image(systemName: "folder")
                    }
                    .help("选择图片")
                    
                    Button(action: { selectedImage = nil; recognizedText = ""; errorMessage = nil }) {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(selectedImage == nil)
                    .help("清空")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 图片显示区
            ZStack {
                // 透明背景网格
                CheckerboardBackground()
                
                if let image = selectedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        
                        Text("拖放图片到这里")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("或点击上方按钮选择 / 粘贴图片")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // 处理中遮罩
                if isProcessing {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在识别...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                
                // 拖拽高亮
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .padding(8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
            
            // 识别按钮
            if selectedImage != nil {
                Button(action: performOCR) {
                    HStack {
                        Image(systemName: "text.viewfinder")
                        Text("开始识别")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing)
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }
    
    // MARK: - 结果面板
    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(.green)
                Text("识别结果")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(recognizedText.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 6)
                
                HStack(spacing: 4) {
                    Button(action: copyResult) {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(recognizedText.isEmpty)
                    .help("复制")
                    
                    Button(action: saveResult) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(recognizedText.isEmpty)
                    .help("保存")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 结果显示
            ScrollView {
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else if recognizedText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("识别结果将显示在这里")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if selectedImage != nil {
                            Text("点击「开始识别」按钮进行 OCR 识别")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    Text(recognizedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
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
