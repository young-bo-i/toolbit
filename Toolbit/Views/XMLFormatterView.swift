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
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HStack(spacing: 16) {
                // 左侧：输入区域
                inputPanel
                
                // 右侧：输出区域
                outputPanel
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
            triggerDebouncedFormat()
        }
        .onChange(of: indentSpaces) { _, _ in
            formatXML()
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("XML 格式化")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("格式化和美化 XML 数据")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 配置选项
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text("缩进:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $indentSpaces) {
                        Text("2 空格").tag(2)
                        Text("4 空格").tag(4)
                        Text("Tab").tag(-1)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }
            
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("输入 XML")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: pasteInput) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !inputText.isEmpty {
                        Button(action: compressXML) {
                            Label("压缩", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button(action: { inputText = "" }) {
                            Label("清空", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $inputText)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                
                if inputText.isEmpty {
                    Text("粘贴或输入 XML 数据...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 错误信息
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.1))
                }
            }
        }
    }
    
    // MARK: - 输出面板
    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("格式化结果")
                    .font(.headline)
                Spacer()
                
                if !outputText.isEmpty {
                    Text("\(outputText.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: copyOutput) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
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
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
    }
}

#Preview {
    XMLFormatterView()
        .frame(width: 900, height: 600)
}
