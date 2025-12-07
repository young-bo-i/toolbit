import SwiftUI
import AppKit

struct Base64TextView: View {
    @State private var inputText: String = ""
    @State private var encodedResult: String = ""
    @State private var decodedResult: String = ""
    @State private var decodeError: String?
    @State private var hasInitialized: Bool = false
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            VStack(spacing: 16) {
                // 输入框
                inputPanel
                
                // 结果区域
                HStack(spacing: 16) {
                    // 编码结果
                    resultPanel(
                        title: "Base64 编码结果",
                        content: encodedResult,
                        placeholder: "输入文本后自动显示编码结果...",
                        error: nil,
                        onCopy: { copyToClipboard(encodedResult) }
                    )
                    
                    // 解码结果
                    resultPanel(
                        title: "Base64 解码结果",
                        content: decodedResult,
                        placeholder: "输入 Base64 编码后自动显示解码结果...",
                        error: decodeError,
                        onCopy: { copyToClipboard(decodedResult) }
                    )
                }
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
            inputText = ""
            encodedResult = ""
            decodedResult = ""
            decodeError = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in
            triggerDebouncedProcess()
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base64 文本")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("输入文本自动进行 Base64 编码和解码")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: clearAll) {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(inputText.isEmpty)
        }
        .padding()
    }
    
    // MARK: - 输入面板
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("输入文本")
                    .font(.headline)
                
                Spacer()
                
                Text("\(inputText.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button(action: pasteFromClipboard) {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if !inputText.isEmpty {
                    Button(action: { inputText = "" }) {
                        Label("清空", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled(true)
                .padding(12)
                .frame(height: 120)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    if inputText.isEmpty {
                        Text("输入普通文本进行编码，或输入 Base64 编码进行解码...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
    
    // MARK: - 结果面板
    private func resultPanel(
        title: String,
        content: String,
        placeholder: String,
        error: String?,
        onCopy: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !content.isEmpty {
                    Text("\(content.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: onCopy) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                if let error = error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if content.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                } else {
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedProcess() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    processInput()
                }
            }
        }
    }
    
    private func processInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text.isEmpty {
            encodedResult = ""
            decodedResult = ""
            decodeError = nil
            return
        }
        
        // 编码：将输入文本编码为 Base64
        if let data = text.data(using: .utf8) {
            encodedResult = data.base64EncodedString()
        } else {
            encodedResult = ""
        }
        
        // 解码：尝试将输入文本作为 Base64 解码
        decodeBase64(text)
    }
    
    private func decodeBase64(_ text: String) {
        // 清理输入
        let cleanText = text
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        // 尝试解码
        if let data = Data(base64Encoded: cleanText),
           let decoded = String(data: data, encoding: .utf8) {
            decodedResult = decoded
            decodeError = nil
        } else if let data = Data(base64Encoded: cleanText, options: .ignoreUnknownCharacters),
                  let decoded = String(data: data, encoding: .utf8) {
            decodedResult = decoded
            decodeError = nil
        } else {
            decodedResult = ""
            decodeError = "输入不是有效的 Base64 编码"
        }
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 10000 { // 限制长度避免卡顿
                inputText = trimmed
            }
        }
    }
    
    private func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            inputText = string
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func clearAll() {
        inputText = ""
        encodedResult = ""
        decodedResult = ""
        decodeError = nil
    }
}

#Preview {
    Base64TextView()
        .frame(width: 900, height: 600)
}

