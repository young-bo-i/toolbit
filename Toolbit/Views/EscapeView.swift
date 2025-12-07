import SwiftUI
import AppKit

struct EscapeView: View {
    @State private var inputText: String = ""
    @State private var escapedText: String = ""
    @State private var unescapedText: String = ""
    @State private var escapeError: String?
    @State private var unescapeError: String?
    @State private var hasInitialized: Bool = false
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // 输入区域
            VStack(alignment: .leading, spacing: 0) {
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
                        Button(action: pasteInput) {
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
                
                ZStack(alignment: .topLeading) {
                    CodeEditor(text: $inputText)
                        .frame(height: 150)
                    
                    if inputText.isEmpty {
                        Text("输入需要转义或反转义的文本...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
            
            Divider()
            
            // 结果区域
            HStack(spacing: 0) {
                // 转义结果
                resultSection(
                    title: "转义结果",
                    text: escapedText,
                    error: escapeError,
                    copyAction: { copyToClipboard(escapedText) }
                )
                
                Divider()
                
                // 反转义结果
                resultSection(
                    title: "反转义结果",
                    text: unescapedText,
                    error: unescapeError,
                    copyAction: { copyToClipboard(unescapedText) }
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
            escapedText = ""
            unescapedText = ""
            escapeError = nil
            unescapeError = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in
            triggerDebouncedProcess()
        }
    }
    
    // MARK: - 结果区域
    private func resultSection(title: String, text: String, error: String?, copyAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !text.isEmpty {
                    Text("\(text.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    
                    Button(action: copyAction) {
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
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(16)
                } else if text.isEmpty {
                    Text("结果将显示在这里...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                } else {
                    ScrollView {
                        Text(text)
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
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            if !Task.isCancelled {
                await MainActor.run {
                    processText()
                }
            }
        }
    }
    
    private func processText() {
        guard !inputText.isEmpty else {
            escapedText = ""
            unescapedText = ""
            escapeError = nil
            unescapeError = nil
            return
        }
        
        // 转义处理
        escapeText()
        
        // 反转义处理
        unescapeText()
    }
    
    private func escapeText() {
        var result = inputText
        
        // 转义特殊字符
        result = result
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\0", with: "\\0")
        
        escapedText = result
        escapeError = nil
    }
    
    private func unescapeText() {
        var result = inputText
        
        // 反转义处理 - 注意顺序很重要
        result = result
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\0", with: "\0")
            .replacingOccurrences(of: "\\'", with: "'")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
        
        unescapedText = result
        unescapeError = nil
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
    
    private func pasteInput() {
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
    EscapeView()
        .frame(width: 900, height: 600)
}
