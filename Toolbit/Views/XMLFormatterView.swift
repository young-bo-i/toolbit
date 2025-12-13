import SwiftUI
import AppKit

struct XMLFormatterView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var indentSpaces: Int = 2
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
            HStack(spacing: 16) {
            // 左侧：输入
                inputPanel
                
            // 右侧：输出
                outputPanel
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
            outputText = ""
            errorMessage = nil
            hasInitialized = false
        }
        .onChange(of: inputText) { _, _ in triggerDebouncedFormat() }
        .onChange(of: indentSpaces) { _, _ in formatXML() }
    }
    
    // MARK: - 输入面板
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.green)
                Text("输入 XML")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(inputText.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 6)
                
                HStack(spacing: 4) {
                    Button(action: pasteInput) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("粘贴")
                    
                        Button(action: compressXML) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        }
                    .disabled(inputText.isEmpty)
                    .help("压缩 XML")
                        
                        Button(action: { inputText = "" }) {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(inputText.isEmpty)
                    .help("清空")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 输入编辑器
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $inputText)
                
                if inputText.isEmpty {
                    Text("粘贴或输入 XML 数据...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            
            // 错误信息
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text(error)
                }
                        .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }
    
    // MARK: - 输出面板
    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.blue)
                Text("格式化结果")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Picker("", selection: $indentSpaces) {
                    Text("2空格").tag(2)
                    Text("4空格").tag(4)
                    Text("Tab").tag(-1)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 6)
                
                    Text("\(outputText.count) 字符")
                        .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    
                    Button(action: copyOutput) {
                    Image(systemName: "doc.on.doc")
                    }
                .buttonStyle(.borderless)
                .disabled(outputText.isEmpty)
                .foregroundStyle(.secondary)
                .help("复制")
                }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 输出显示
            ScrollView {
                if outputText.isEmpty {
                    Text("格式化结果将显示在这里...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                } else {
                        Text(outputText)
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
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedFormat() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !Task.isCancelled {
                await MainActor.run { formatXML() }
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
            
            if indentSpaces == 2 {
                formattedString = formattedString.replacingOccurrences(of: "    ", with: "  ")
            } else if indentSpaces == -1 {
                formattedString = formattedString.replacingOccurrences(of: "    ", with: "\t")
            }
            
            outputText = formattedString
            errorMessage = nil
        } catch {
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
        result = result.replacingOccurrences(of: ">\\s+<", with: "><", options: .regularExpression)
        result = result.replacingOccurrences(of: "><", with: ">\n<")
        
        let lines = result.components(separatedBy: "\n")
        var indentLevel = 0
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            let isClosingTag = trimmedLine.hasPrefix("</")
            let isSelfClosing = trimmedLine.hasSuffix("/>")
            let isOpeningTag = trimmedLine.hasPrefix("<") && !isClosingTag && !trimmedLine.hasPrefix("<?") && !trimmedLine.hasPrefix("<!")
            
            if isClosingTag {
                indentLevel = max(0, indentLevel - 1)
            }
            
            let currentIndent = String(repeating: indent, count: indentLevel)
            formattedLines.append(currentIndent + trimmedLine)
            
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
        if let string = NSPasteboard.general.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("<") && trimmed.hasSuffix(">") {
                inputText = trimmed
            }
        }
    }
    
    private func pasteInput() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputText = string
        }
    }
    
    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }
}

#Preview {
    XMLFormatterView()
        .frame(width: 900, height: 600)
}
