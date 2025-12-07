import SwiftUI
import AppKit

struct XMLFormatterView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var indentSpaces: Int = 2
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：输入区域
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("输入 XML")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(action: pasteInput) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
                        Button(action: compressXML) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                        }
                        .buttonStyle(.borderless)
                        .disabled(inputText.isEmpty)
                        .help("压缩")
                        
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
                    
                    if inputText.isEmpty {
                        Text("粘贴或输入 XML 数据...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                
                // 错误信息
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                }
            }
            .frame(minWidth: 300)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
            
            Divider()
            
            // 右侧：输出区域
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("格式化结果")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 配置选项
                    Picker("", selection: $indentSpaces) {
                        Text("2空格").tag(2)
                        Text("4空格").tag(4)
                        Text("Tab").tag(-1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    
                    Divider()
                        .frame(height: 16)
                    
                    HStack(spacing: 8) {
                        if !outputText.isEmpty {
                            Text("\(outputText.count)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        
                        Button(action: copyOutput) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .disabled(outputText.isEmpty)
                        .help("复制")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                ZStack(alignment: .topLeading) {
                    if outputText.isEmpty {
                        Text("格式化结果将显示在这里...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                    } else {
                        ScrollView {
                            Text(outputText)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 300)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
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
            outputText = ""
            errorMessage = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in
            triggerDebouncedFormat()
        }
        .onChange(of: indentSpaces) { _, _ in
            formatXML()
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedFormat() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            if !Task.isCancelled {
                await MainActor.run {
                    formatXML()
                }
            }
        }
    }
    
    private func formatXML() {
        guard !inputText.isEmpty else {
            outputText = ""
            errorMessage = nil
            return
        }
        
        let indent = indentSpaces == -1 ? "\t" : String(repeating: " ", count: indentSpaces)
        
        do {
            let xmlDoc = try XMLDocument(xmlString: inputText, options: [.nodePrettyPrint, .nodePreserveWhitespace])
            var formattedString = xmlDoc.xmlString(options: [.nodePrettyPrint])
            
            // 处理缩进
            if indentSpaces == 2 {
                formattedString = formattedString.replacingOccurrences(of: "    ", with: "  ")
            } else if indentSpaces == -1 {
                formattedString = formattedString.replacingOccurrences(of: "    ", with: "\t")
            }
            
            outputText = formattedString
            errorMessage = nil
        } catch {
            // 尝试简单格式化
            outputText = simpleFormatXML(inputText, indent: indent)
            if outputText.isEmpty {
                errorMessage = "XML 解析错误: \(error.localizedDescription)"
            } else {
                errorMessage = nil
            }
        }
    }
    
    private func simpleFormatXML(_ xml: String, indent: String) -> String {
        var result = xml
        
        // 移除现有的换行和多余空格
        result = result.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
        
        // 在标签之间添加换行
        result = result.replacingOccurrences(of: "><", with: ">\n<")
        
        // 添加缩进
        let lines = result.components(separatedBy: "\n")
        var indentLevel = 0
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            // 检查是否是结束标签
            let isClosingTag = trimmedLine.hasPrefix("</")
            let isSelfClosing = trimmedLine.hasSuffix("/>")
            let isOpeningTag = trimmedLine.hasPrefix("<") && !isClosingTag && !trimmedLine.hasPrefix("<?") && !trimmedLine.hasPrefix("<!")
            
            // 结束标签减少缩进
            if isClosingTag {
                indentLevel = max(0, indentLevel - 1)
            }
            
            // 添加缩进
            let currentIndent = String(repeating: indent, count: indentLevel)
            formattedLines.append(currentIndent + trimmedLine)
            
            // 开始标签增加缩进（非自闭合）
            if isOpeningTag && !isSelfClosing && !trimmedLine.contains("</") {
                indentLevel += 1
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    private func compressXML() {
        inputText = inputText
            .replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
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
    
    private func copyOutput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
}

#Preview {
    XMLFormatterView()
        .frame(width: 900, height: 600)
}
