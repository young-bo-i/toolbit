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
            formatJSON()
        }
        .onChange(of: sortKeys) { _, _ in
            formatJSON()
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("JSON 格式化")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("格式化和美化 JSON 数据")
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
                
                Toggle("按字母排序", isOn: $sortKeys)
                    .toggleStyle(.checkbox)
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
                Text("输入 JSON")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: pasteInput) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !inputText.isEmpty {
                        Button(action: compressJSON) {
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
                    Text("粘贴或输入 JSON 数据...")
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
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
    }
}

#Preview {
    JSONFormatterView()
        .frame(width: 900, height: 600)
}
