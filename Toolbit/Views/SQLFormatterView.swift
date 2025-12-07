import SwiftUI
import AppKit

enum SQLDialect: String, CaseIterable, Identifiable {
    case standard = "标准 SQL"
    case mysql = "MySQL"
    case postgresql = "PostgreSQL"
    case sqlite = "SQLite"
    case oracle = "Oracle"
    case sqlserver = "SQL Server"
    
    var id: String { rawValue }
}

struct SQLFormatterView: View {
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var hasInitialized: Bool = false
    @State private var indentSpaces: Int = 2
    @State private var sqlDialect: SQLDialect = .standard
    
    // 防抖任务
    @State private var debounceTask: Task<Void, Never>?
    
    // SQL 关键字
    private let keywords = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "IS", "NULL",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "FULL", "CROSS", "ON",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
        "CREATE", "TABLE", "INDEX", "VIEW", "DROP", "ALTER", "ADD", "COLUMN",
        "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "UNIQUE",
        "ORDER", "BY", "ASC", "DESC", "GROUP", "HAVING", "LIMIT", "OFFSET",
        "UNION", "ALL", "EXCEPT", "INTERSECT", "AS", "DISTINCT", "TOP",
        "CASE", "WHEN", "THEN", "ELSE", "END", "EXISTS", "BETWEEN", "LIKE",
        "COUNT", "SUM", "AVG", "MIN", "MAX", "CAST", "CONVERT", "COALESCE",
        "IF", "BEGIN", "COMMIT", "ROLLBACK", "TRANSACTION", "WITH", "RECURSIVE"
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：输入区域
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("输入 SQL")
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
                        
                        Button(action: compressSQL) {
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
                        Text("粘贴或输入 SQL 语句...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(16)
                            .allowsHitTesting(false)
                    }
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
                    HStack(spacing: 12) {
                        Picker("", selection: $sqlDialect) {
                            ForEach(SQLDialect.allCases) { dialect in
                                Text(dialect.rawValue).tag(dialect)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                        
                        Picker("", selection: $indentSpaces) {
                            Text("2空格").tag(2)
                            Text("4空格").tag(4)
                            Text("Tab").tag(-1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                    
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
            formatSQL()
        }
        .onChange(of: sqlDialect) { _, _ in
            formatSQL()
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedFormat() {
        debounceTask?.cancel()
        
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            if !Task.isCancelled {
                await MainActor.run {
                    formatSQL()
                }
            }
        }
    }
    
    private func formatSQL() {
        guard !inputText.isEmpty else {
            outputText = ""
            errorMessage = nil
            return
        }
        
        let indent = indentSpaces == -1 ? "\t" : String(repeating: " ", count: indentSpaces)
        outputText = formatSQLString(inputText, indent: indent)
        errorMessage = nil
    }
    
    private func formatSQLString(_ sql: String, indent: String) -> String {
        var result = sql
        
        // 标准化空白字符
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 主要关键字前换行
        let newlineBeforeKeywords = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN", "FULL JOIN", "CROSS JOIN", "ORDER BY", "GROUP BY", "HAVING", "LIMIT", "OFFSET", "UNION", "EXCEPT", "INTERSECT", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP", "ALTER", "ON"]
        
        for keyword in newlineBeforeKeywords {
            // 匹配关键字（不区分大小写）
            let pattern = "(?i)\\s+\(keyword)\\b"
            result = result.replacingOccurrences(of: pattern, with: "\n\(keyword.uppercased())", options: .regularExpression)
        }
        
        // 逗号后换行并缩进（在 SELECT 子句中）
        result = formatSelectClause(result, indent: indent)
        
        // 添加缩进
        let lines = result.components(separatedBy: "\n")
        var indentLevel = 0
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            // 检查是否需要减少缩进
            let upperLine = trimmedLine.uppercased()
            if upperLine.hasPrefix(")") || upperLine.hasPrefix("END") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            // 添加缩进
            let currentIndent = String(repeating: indent, count: indentLevel)
            
            // 关键字大写处理
            var processedLine = trimmedLine
            for keyword in keywords {
                let pattern = "\\b\(keyword)\\b"
                processedLine = processedLine.replacingOccurrences(of: pattern, with: keyword, options: [.regularExpression, .caseInsensitive])
            }
            
            formattedLines.append(currentIndent + processedLine)
            
            // 检查是否需要增加缩进
            if upperLine.hasSuffix("(") || upperLine.hasPrefix("BEGIN") || upperLine.hasPrefix("CASE") {
                indentLevel += 1
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    private func formatSelectClause(_ sql: String, indent: String) -> String {
        var result = sql
        
        // 在 SELECT 和 FROM 之间的逗号后添加换行
        if let selectRange = result.range(of: "SELECT", options: .caseInsensitive),
           let fromRange = result.range(of: "FROM", options: .caseInsensitive, range: selectRange.upperBound..<result.endIndex) {
            let selectClause = String(result[selectRange.upperBound..<fromRange.lowerBound])
            let formattedSelect = selectClause.replacingOccurrences(of: ",", with: ",\n\(indent)")
            result = result.replacingCharacters(in: selectRange.upperBound..<fromRange.lowerBound, with: formattedSelect)
        }
        
        return result
    }
    
    private func compressSQL() {
        inputText = inputText
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let sqlKeywords = ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "ALTER"]
            if sqlKeywords.contains(where: { trimmed.hasPrefix($0) }) {
                inputText = string.trimmingCharacters(in: .whitespacesAndNewlines)
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
    SQLFormatterView()
        .frame(width: 900, height: 600)
}
