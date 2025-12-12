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
    @State private var debounceTask: Task<Void, Never>?
    
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
        .onChange(of: indentSpaces) { _, _ in formatSQL() }
        .onChange(of: sqlDialect) { _, _ in formatSQL() }
    }
    
    // MARK: - 输入面板
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "tablecells")
                    .foregroundStyle(.purple)
                Text("输入 SQL")
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
                    
                    Button(action: compressSQL) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                    }
                    .disabled(inputText.isEmpty)
                    .help("压缩 SQL")
                    
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
                    Text("粘贴或输入 SQL 语句...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .allowsHitTesting(false)
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
    
    // MARK: - 操作方法
    
    private func triggerDebouncedFormat() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            if !Task.isCancelled {
                await MainActor.run { formatSQL() }
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
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let newlineBeforeKeywords = ["SELECT", "FROM", "WHERE", "AND", "OR", "JOIN", "LEFT JOIN", "RIGHT JOIN", "INNER JOIN", "OUTER JOIN", "FULL JOIN", "CROSS JOIN", "ORDER BY", "GROUP BY", "HAVING", "LIMIT", "OFFSET", "UNION", "EXCEPT", "INTERSECT", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "DROP", "ALTER", "ON"]
        
        for keyword in newlineBeforeKeywords {
            let pattern = "(?i)\\s+\(keyword)\\b"
            result = result.replacingOccurrences(of: pattern, with: "\n\(keyword.uppercased())", options: .regularExpression)
        }
        
        result = formatSelectClause(result, indent: indent)
        
        let lines = result.components(separatedBy: "\n")
        var indentLevel = 0
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty { continue }
            
            let upperLine = trimmedLine.uppercased()
            if upperLine.hasPrefix(")") || upperLine.hasPrefix("END") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            let currentIndent = String(repeating: indent, count: indentLevel)
            
            var processedLine = trimmedLine
            for keyword in keywords {
                let pattern = "\\b\(keyword)\\b"
                processedLine = processedLine.replacingOccurrences(of: pattern, with: keyword, options: [.regularExpression, .caseInsensitive])
            }
            
            formattedLines.append(currentIndent + processedLine)
            
            if upperLine.hasSuffix("(") || upperLine.hasPrefix("BEGIN") || upperLine.hasPrefix("CASE") {
                indentLevel += 1
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    private func formatSelectClause(_ sql: String, indent: String) -> String {
        var result = sql
        
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
        if let string = NSPasteboard.general.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let sqlKeywords = ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "DROP", "ALTER"]
            if sqlKeywords.contains(where: { trimmed.hasPrefix($0) }) {
                inputText = string.trimmingCharacters(in: .whitespacesAndNewlines)
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
    SQLFormatterView()
        .frame(width: 900, height: 600)
}
