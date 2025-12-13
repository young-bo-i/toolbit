import SwiftUI
import AppKit

struct JSONFormatterView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var indentSpaces: Int = 2
    @State private var sortKeys: Bool = false
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
        .onChange(of: indentSpaces) { _, _ in formatJSON() }
        .onChange(of: sortKeys) { _, _ in formatJSON() }
    }
    
    // MARK: - 输入面板
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "curlybraces")
                    .foregroundStyle(.orange)
                Text("输入 JSON")
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
                    
                        Button(action: compressJSON) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        }
                    .disabled(inputText.isEmpty)
                    .help("压缩 JSON")
                        
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
                    Text("粘贴或输入 JSON 数据...")
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
                
                // 配置选项
                HStack(spacing: 8) {
                    Picker("", selection: $indentSpaces) {
                        Text("2空格").tag(2)
                        Text("4空格").tag(4)
                        Text("Tab").tag(-1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                    
                    Toggle("排序键", isOn: $sortKeys)
                        .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
                
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
                await MainActor.run { formatJSON() }
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
            
            if sortKeys {
                jsonObject = sortJSONKeys(jsonObject)
            }
            
            var options: JSONSerialization.WritingOptions = [.prettyPrinted]
            if sortKeys {
                options.insert(.sortedKeys)
            }
            
            let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)
            
            if var formattedString = String(data: formattedData, encoding: .utf8) {
                if indentSpaces == -1 {
                    formattedString = formattedString.replacingOccurrences(of: "    ", with: "\t")
                } else if indentSpaces == 2 {
                    formattedString = formattedString.replacingOccurrences(of: "    ", with: "  ")
                }
                
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
        if let string = NSPasteboard.general.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
               (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
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
    JSONFormatterView()
        .frame(width: 900, height: 600)
}
