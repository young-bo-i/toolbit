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
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            VStack(spacing: 16) {
                // 输入区域
                inputSection
                
                // 结果区域
                HStack(spacing: 16) {
                    // 转义结果
                    resultSection(
                        title: "转义结果",
                        text: escapedText,
                        error: escapeError,
                        copyAction: { copyToClipboard(escapedText) }
                    )
                    
                    // 反转义结果
                    resultSection(
                        title: "反转义结果",
                        text: unescapedText,
                        error: unescapeError,
                        copyAction: { copyToClipboard(unescapedText) }
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
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("转义/反转义")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("对特殊字符进行转义和反转义处理")
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
    
    // MARK: - 输入区域
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入文本")
                    .font(.headline)
                Spacer()
                
                if !inputText.isEmpty {
                    Text("\(inputText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(action: pasteInput) {
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
            
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $inputText)
                    .frame(height: 150)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                
                if inputText.isEmpty {
                    Text("输入需要转义或反转义的文本...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 结果区域
    private func resultSection(title: String, text: String, error: String?, copyAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                
                if !text.isEmpty {
                    Text("\(text.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: copyAction) {
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
    
    private func clearAll() {
        inputText = ""
        escapedText = ""
        unescapedText = ""
        escapeError = nil
        unescapeError = nil
    }
}

#Preview {
    EscapeView()
        .frame(width: 900, height: 600)
}
