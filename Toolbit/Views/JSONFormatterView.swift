import SwiftUI
import AppKit

struct JSONFormatterView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var indentSpaces: Int = 2
    @State private var sortKeys: Bool = false
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：输入区域
            VStack(alignment: .leading, spacing: 0) {
                // 输入区标题栏
                HStack {
                    Text("输入 JSON")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 8) {
                        Button(action: pasteInput) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
                        Button(action: compressJSON) {
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
                
                // 输入编辑器
                ZStack(alignment: .topLeading) {
                    CodeEditor(text: $inputText)
                    
                    if inputText.isEmpty {
                        Text("粘贴或输入 JSON 数据...")
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
                // 输出区标题栏
                HStack {
                    Text("格式化结果")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 配置选项
                    HStack(spacing: 12) {
                        Picker("", selection: $indentSpaces) {
                            Text("2空格").tag(2)
                            Text("4空格").tag(4)
                            Text("Tab").tag(-1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        
                        Toggle("排序", isOn: $sortKeys)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                    }
                    
                    Divider()
                        .frame(height: 16)
                    
                    // 操作按钮
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
                
                // 输出显示
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
            formatJSON()
        }
        .onChange(of: sortKeys) { _, _ in
            formatJSON()
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedFormat() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            if !Task.isCancelled {
                await MainActor.run {
                    formatJSON()
                }
            }
        }
    }
    
    private func formatJSON() {
        guard !inputText.isEmpty else {
            outputText = ""
            errorMessage = nil
            return
        }
        
        guard let data = inputText.data(using: .utf8) else {
            errorMessage = "无法解析输入文本"
            return
        }
        
        do {
            var jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            
            // 如果需要排序
            if sortKeys {
                jsonObject = sortJSONKeys(jsonObject)
            }
            
            var options: JSONSerialization.WritingOptions = [.prettyPrinted]
            if sortKeys {
                options.insert(.sortedKeys)
            }
            
            let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            
            if var formattedString = String(data: formattedData, encoding: .utf8) {
                // 处理缩进
                if indentSpaces == -1 {
                    // Tab 缩进
                    formattedString = formattedString.replacingOccurrences(of: "    ", with: "\t")
                } else if indentSpaces == 2 {
                    // 2 空格缩进（默认是 4 空格，需要替换）
                    formattedString = formattedString.replacingOccurrences(of: "    ", with: "  ")
                }
                // 4 空格是默认的，不需要处理
                
                outputText = formattedString
                errorMessage = nil
            }
        } catch {
            errorMessage = "JSON 解析错误: \(error.localizedDescription)"
            outputText = ""
        }
    }
    
    private func sortJSONKeys(_ json: Any) -> Any {
        if let dict = json as? [String: Any] {
            var sortedDict: [String: Any] = [:]
            for key in dict.keys.sorted() {
                sortedDict[key] = sortJSONKeys(dict[key]!)
            }
            return sortedDict
        } else if let array = json as? [Any] {
            return array.map { sortJSONKeys($0) }
        }
        return json
    }
    
    private func compressJSON() {
        guard let data = inputText.data(using: .utf8) else { return }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let compressedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            if let compressedString = String(data: compressedData, encoding: .utf8) {
                inputText = compressedString
            }
        } catch {
            errorMessage = "JSON 解析错误"
        }
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
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
    JSONFormatterView()
        .frame(width: 900, height: 600)
}
