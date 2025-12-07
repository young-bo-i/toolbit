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
            // 输入区
            VStack(alignment: .leading, spacing: 0) {
                // 标题栏
                HStack {
                    Text("输入文本")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if !inputText.isEmpty {
                        Text("\(inputText.count) 字符")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    HStack(spacing: 8) {
                        Button(action: pasteFromClipboard) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
                        Button(action: { inputText = "" }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .disabled(inputText.isEmpty)
                        .help("清空")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .frame(height: 120)
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
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
            
            Divider()
            
            // 结果区域
            HStack(spacing: 0) {
                // 编码结果
                resultPanel(
                    title: "URL 编码结果",
                    content: encodedResult,
                    error: nil,
                    onCopy: { copyToClipboard(encodedResult) }
                )
                
                Divider()
                
                // 解码结果
                resultPanel(
                    title: "URL 解码结果",
                    content: decodedResult,
                    error: decodeError,
                    onCopy: { copyToClipboard(decodedResult) }
                )
            }
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
    
    // MARK: - 结果面板
    private func resultPanel(
        title: String,
        content: String,
        error: String?,
        onCopy: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !content.isEmpty {
                    Text("\(content.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("复制")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            ZStack(alignment: .topLeading) {
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
                    Text("结果将显示在这里...")
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
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
}

#Preview {
    URLCoderView()
        .frame(width: 900, height: 600)
}
