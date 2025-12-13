import SwiftUI
import AppKit

struct URLCoderView: View {
    @State private var inputText: String = ""
    @State private var encodedResult: String = ""
    @State private var decodedResult: String = ""
    @State private var decodeError: String?
    @State private var hasInitialized: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var copiedType: CopiedType?
    
    enum CopiedType {
        case encoded, decoded
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 输入区域
            VStack(alignment: .leading, spacing: 0) {
            // 标题栏
                HStack {
                    Text("输入文本")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(inputText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
            
            Divider()
                        .frame(height: 12)
                        .padding(.horizontal, 8)
                    
                    HStack(spacing: 4) {
                        Button(action: pasteFromClipboard) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .help("粘贴")
                        
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle")
                        }
                        .disabled(inputText.isEmpty)
                        .help("清空")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
                
                // 文本输入
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                    
                    if inputText.isEmpty {
                        Text("输入 URL 或文本进行编码/解码...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
                
                // 结果区域
                HStack(spacing: 16) {
                    // 编码结果
                    resultPanel(
                    title: "编码结果",
                    subtitle: "Encode",
                        content: encodedResult,
                        error: nil,
                    icon: "link.badge.plus",
                    color: .blue,
                    isCopied: copiedType == .encoded,
                    onCopy: {
                        copyToClipboard(encodedResult)
                        showCopied(.encoded)
                    }
                    )
                    
                    // 解码结果
                    resultPanel(
                    title: "解码结果",
                    subtitle: "Decode",
                        content: decodedResult,
                        error: decodeError,
                    icon: "link",
                    color: .green,
                    isCopied: copiedType == .decoded,
                    onCopy: {
                        copyToClipboard(decodedResult)
                        showCopied(.decoded)
                    }
                    )
                }
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
            encodedResult = ""
            decodedResult = ""
            decodeError = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in triggerDebouncedProcess() }
    }
    
    // MARK: - 结果面板
    private func resultPanel(
        title: String,
        subtitle: String,
        content: String,
        error: String?,
        icon: String,
        color: Color,
        isCopied: Bool,
        onCopy: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                VStack(alignment: .leading, spacing: 0) {
                Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                if !content.isEmpty {
                    Text("\(content.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                    
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            if isCopied {
                                Text("已复制")
                            }
                    }
                        .font(.caption)
                        .foregroundStyle(isCopied ? .green : .secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 内容区
            ScrollView {
                if let error = error, content.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                } else if content.isEmpty {
                    Text("结果将显示在这里...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
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
                .stroke(color.opacity(0.3), lineWidth: 1)
        }
    }
    
    // MARK: - 复制反馈
    private func showCopied(_ type: CopiedType) {
        copiedType = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedType == type {
                copiedType = nil
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedProcess() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if !Task.isCancelled {
                await MainActor.run { processInput() }
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
        
        encodeURL(text)
        decodeURL(text)
    }
    
    private func encodeURL(_ text: String) {
        var allowedCharacters = CharacterSet.urlQueryAllowed
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
        if let string = NSPasteboard.general.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 10000 {
                inputText = trimmed
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputText = string
        }
    }
    
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

#Preview {
    URLCoderView()
        .frame(width: 900, height: 600)
}
