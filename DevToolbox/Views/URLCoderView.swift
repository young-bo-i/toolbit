import SwiftUI
import AppKit

struct URLCoderView: View {
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
                        title: "URL 编码结果",
                        content: encodedResult,
                        placeholder: "输入文本后自动显示 URL 编码结果...",
                        error: nil,
                        onCopy: { copyToClipboard(encodedResult) }
                    )
                    
                    // 解码结果
                    resultPanel(
                        title: "URL 解码结果",
                        content: decodedResult,
                        placeholder: "输入 URL 编码后自动显示解码结果...",
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
        .onChange(of: inputText) { _, _ in
            triggerDebouncedProcess()
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("URL 编解码")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("输入文本自动进行 URL 编码和解码（百分号编码）")
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
                        Text("输入普通文本或 URL 进行编码，或输入已编码的 URL 进行解码...")
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
        let text = inputText
        
        if text.isEmpty {
            encodedResult = ""
            decodedResult = ""
            decodeError = nil
            return
        }
        
        // URL 编码
        encodeURL(text)
        
        // URL 解码
        decodeURL(text)
    }
    
    private func encodeURL(_ text: String) {
        // 使用完整的 URL 编码，包括特殊字符
        var allowedCharacters = CharacterSet.urlQueryAllowed
        // 移除一些通常需要编码的字符
        allowedCharacters.remove(charactersIn: "!*'();:@&=+$,/?#[]")
        
        if let encoded = text.addingPercentEncoding(withAllowedCharacters: allowedCharacters) {
            encodedResult = encoded
        } else {
            encodedResult = text
        }
    }
    
    private func decodeURL(_ text: String) {
        if let decoded = text.removingPercentEncoding {
            decodedResult = decoded
            decodeError = nil
        } else {
            decodedResult = ""
            decodeError = "无法解码，可能包含无效的百分号编码"
        }
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 10000 {
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
    URLCoderView()
        .frame(width: 900, height: 600)
}

