import SwiftUI
import AppKit

struct EscapeView: View {
    @State private var inputText: String = ""
    @State private var escapedText: String = ""
    @State private var unescapedText: String = ""
    @State private var hasInitialized: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var copiedType: CopiedType?
    
    enum CopiedType {
        case escaped, unescaped
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
                        Button(action: pasteInput) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(inputText.isEmpty)
                        .help("清空")
                    }
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
                        Text("输入需要转义或反转义的文本...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            
            // 结果区域 - 左右两栏
                HStack(spacing: 16) {
                    // 转义结果
                resultPanel(
                        title: "转义结果",
                    subtitle: "Escape",
                    content: escapedText,
                    icon: "arrow.right.square",
                    color: .blue,
                    isCopied: copiedType == .escaped,
                    onCopy: {
                        copyToClipboard(escapedText)
                        showCopied(.escaped)
                    }
                    )
                    
                    // 反转义结果
                resultPanel(
                        title: "反转义结果",
                    subtitle: "Unescape",
                    content: unescapedText,
                    icon: "arrow.left.square",
                    color: .green,
                    isCopied: copiedType == .unescaped,
                    onCopy: {
                        copyToClipboard(unescapedText)
                        showCopied(.unescaped)
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
            escapedText = ""
            unescapedText = ""
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in triggerDebouncedProcess() }
    }
    
    // MARK: - 结果面板
    private func resultPanel(
        title: String,
        subtitle: String,
        content: String,
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
                    .help("复制结果")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 内容区
            ScrollView {
                if content.isEmpty {
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
    
    // MARK: - 操作方法
    
    private func showCopied(_ type: CopiedType) {
        copiedType = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedType == type {
                copiedType = nil
            }
        }
    }
    
    private func triggerDebouncedProcess() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if !Task.isCancelled {
                await MainActor.run { processText() }
            }
        }
    }
    
    private func processText() {
        guard !inputText.isEmpty else {
            escapedText = ""
            unescapedText = ""
            return
        }
        
        // 转义
        escapedText = inputText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\0", with: "\\0")
        
        // 反转义
        unescapedText = inputText
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\0", with: "\0")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
    
    private func checkPasteboardOnAppear() {
        if let string = NSPasteboard.general.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.count < 10000 {
                inputText = trimmed
            }
        }
    }
    
    private func pasteInput() {
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
    EscapeView()
        .frame(width: 900, height: 600)
}
