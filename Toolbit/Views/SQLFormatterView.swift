import SwiftUI
import AppKit

enum SQLDialect: String, CaseIterable, Identifiable {
    case standard = "标准 SQL"
    case mysql = "MySQL"
    case postgresql = "PostgreSQL"
    case sqlite = "SQLite"
    case oracle = "Oracle"
    case sqlserver = "SQL Server"
    case db2 = "Db2"
    case mariadb = "MariaDB"
    case n1ql = "N1QL"
    case plsql = "PL/SQL"
    case redshift = "Amazon Redshift"
    case spark = "Spark SQL"
    case transactsql = "Transact-SQL"
    
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
        .onDisappear {
            // 切换页面时清空状态
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
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SQL 格式化")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("格式化和美化 SQL 语句")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 配置选项
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text("语言:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $sqlDialect) {
                        ForEach(SQLDialect.allCases) { dialect in
                            Text(dialect.rawValue).tag(dialect)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                
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
                Text("输入 SQL")
                    .font(.headline)
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: pasteInput) {
                        Label("粘贴", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if !inputText.isEmpty {
                        Button(action: compressSQL) {
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
                    Text("粘贴或输入 SQL 语句...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private func clearAll() {
        inputText = ""
        outputText = ""
        errorMessage = nil
    }
}

#Preview {
    SQLFormatterView()
        .frame(width: 900, height: 600)
}
