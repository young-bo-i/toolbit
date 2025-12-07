import SwiftUI
import AppKit
import WebKit

struct MarkdownPreviewView: View {
    @State private var inputText: String = ""
    @State private var hasInitialized: Bool = false
    
    // 示例 Markdown
    private let sampleMarkdown = """
# Markdown 预览示例

## 文本格式

这是**粗体**文本，这是*斜体*文本，这是~~删除线~~文本。

这是`行内代码`示例。

## 列表

### 无序列表
- 项目 1
- 项目 2
  - 子项目 2.1
  - 子项目 2.2
- 项目 3

### 有序列表
1. 第一步
2. 第二步
3. 第三步

## 链接和图片

[访问 GitHub](https://github.com)

## 代码块

```swift
func hello() {
    print("Hello, World!")
}
```

## 引用

> 这是一段引用文本。
> 可以有多行。

## 表格

| 姓名 | 年龄 | 城市 |
|------|------|------|
| 张三 | 25 | 北京 |
| 李四 | 30 | 上海 |
| 王五 | 28 | 广州 |

## 任务列表

- [x] 已完成任务
- [ ] 未完成任务
- [ ] 另一个任务

## 分割线

---

## 数学公式（如果支持）

行内公式：$E = mc^2$

"""
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HSplitView {
                // 左侧：Markdown 输入
                inputPanel
                    .frame(minWidth: 350)
                
                // 右侧：预览
                previewPanel
                    .frame(minWidth: 350)
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
            inputText = ""
            hasInitialized = false
        }
    }
    
    // MARK: - 标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Markdown 预览")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("实时预览 Markdown 文档")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: loadSample) {
                Label("加载示例", systemImage: "doc.text")
            }
            .buttonStyle(.bordered)
            
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
                Text("Markdown 源码")
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
                    Button(action: copyInput) {
                        Label("复制", systemImage: "doc.on.doc")
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
            
            ZStack(alignment: .topLeading) {
                CodeEditor(text: $inputText)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                
                if inputText.isEmpty {
                    Text("输入 Markdown 文本...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 预览面板
    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("预览")
                    .font(.headline)
                Spacer()
                
                Button(action: exportHTML) {
                    Label("导出 HTML", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(inputText.isEmpty)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                if inputText.isEmpty {
                    Text("预览将显示在这里...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                } else {
                    MarkdownWebView(markdown: inputText)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 操作方法
    
    private func checkPasteboardOnAppear() {
        let pasteboard = NSPasteboard.general
        if let string = pasteboard.string(forType: .string) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            // 检查是否可能是 Markdown
            if trimmed.contains("#") || trimmed.contains("```") || trimmed.contains("- ") || trimmed.contains("* ") {
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
    
    private func copyInput() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(inputText, forType: .string)
    }
    
    private func loadSample() {
        inputText = sampleMarkdown
    }
    
    private func clearAll() {
        inputText = ""
    }
    
    private func exportHTML() {
        let html = generateFullHTML(from: inputText)
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "markdown_export.html"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func generateFullHTML(from markdown: String) -> String {
        let bodyHTML = convertMarkdownToHTML(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Markdown Export</title>
            <style>
                \(MarkdownWebView.cssStyles)
            </style>
        </head>
        <body>
            \(bodyHTML)
        </body>
        </html>
        """
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        MarkdownParser.parse(markdown)
    }
}

// MARK: - Markdown WebView
struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    
    static let cssStyles = """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #333;
            padding: 20px;
            max-width: 100%;
            background-color: transparent;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #e0e0e0; }
            a { color: #58a6ff; }
            code { background-color: #2d2d2d; }
            pre { background-color: #2d2d2d; }
            blockquote { border-left-color: #555; color: #aaa; }
            table th { background-color: #2d2d2d; }
            table td, table th { border-color: #444; }
            hr { background-color: #444; }
        }
        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        h1 { font-size: 2em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        p { margin-bottom: 16px; }
        a { color: #0366d6; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code {
            font-family: 'SF Mono', Consolas, 'Liberation Mono', Menlo, monospace;
            font-size: 85%;
            background-color: #f6f8fa;
            padding: 0.2em 0.4em;
            border-radius: 3px;
        }
        pre {
            background-color: #f6f8fa;
            padding: 16px;
            overflow: auto;
            border-radius: 6px;
            line-height: 1.45;
        }
        pre code {
            background-color: transparent;
            padding: 0;
            font-size: 100%;
        }
        blockquote {
            margin: 0 0 16px 0;
            padding: 0 1em;
            color: #666;
            border-left: 4px solid #ddd;
        }
        ul, ol {
            margin-bottom: 16px;
            padding-left: 2em;
        }
        li { margin-bottom: 4px; }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }
        table th, table td {
            border: 1px solid #ddd;
            padding: 8px 12px;
            text-align: left;
        }
        table th {
            background-color: #f6f8fa;
            font-weight: 600;
        }
        table tr:nth-child(even) {
            background-color: rgba(0,0,0,0.02);
        }
        hr {
            height: 2px;
            background-color: #eee;
            border: none;
            margin: 24px 0;
        }
        img {
            max-width: 100%;
            height: auto;
        }
        .task-list-item {
            list-style-type: none;
            margin-left: -1.5em;
        }
        .task-list-item input {
            margin-right: 0.5em;
        }
        del { color: #888; }
    """
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func generateHTML() -> String {
        let bodyHTML = MarkdownParser.parse(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>\(Self.cssStyles)</style>
        </head>
        <body>\(bodyHTML)</body>
        </html>
        """
    }
}

// MARK: - Markdown Parser
struct MarkdownParser {
    static func parse(_ markdown: String) -> String {
        var html = markdown
        
        // 代码块（需要先处理，避免内部内容被其他规则影响）
        html = processCodeBlocks(html)
        
        // 标题
        html = html.replacingOccurrences(of: "(?m)^######\\s+(.+)$", with: "<h6>$1</h6>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#####\\s+(.+)$", with: "<h5>$1</h5>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^####\\s+(.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^###\\s+(.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^##\\s+(.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^#\\s+(.+)$", with: "<h1>$1</h1>", options: .regularExpression)
        
        // 水平线
        html = html.replacingOccurrences(of: "(?m)^---+$", with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\*\\*\\*+$", with: "<hr>", options: .regularExpression)
        
        // 粗体和斜体
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: "__(.+?)__", with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: "_(.+?)_", with: "<em>$1</em>", options: .regularExpression)
        
        // 删除线
        html = html.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)
        
        // 行内代码
        html = html.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // 链接
        html = html.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\" target=\"_blank\">$1</a>", options: .regularExpression)
        
        // 图片
        html = html.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        
        // 引用块
        html = processBlockquotes(html)
        
        // 表格
        html = processTables(html)
        
        // 任务列表
        html = html.replacingOccurrences(of: "(?m)^\\s*-\\s*\\[x\\]\\s+(.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" checked disabled> $1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^\\s*-\\s*\\[\\s\\]\\s+(.+)$", with: "<li class=\"task-list-item\"><input type=\"checkbox\" disabled> $1</li>", options: .regularExpression)
        
        // 无序列表
        html = processUnorderedLists(html)
        
        // 有序列表
        html = processOrderedLists(html)
        
        // 段落
        html = processParagraphs(html)
        
        return html
    }
    
    private static func processCodeBlocks(_ text: String) -> String {
        var result = text
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "<pre><code class=\"language-$1\">$2</code></pre>")
        }
        
        return result
    }
    
    private static func processBlockquotes(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inBlockquote = false
        
        for line in lines {
            if line.hasPrefix("> ") || line.hasPrefix(">") {
                let content = line.replacingOccurrences(of: "^>\\s?", with: "", options: .regularExpression)
                if !inBlockquote {
                    result.append("<blockquote>")
                    inBlockquote = true
                }
                result.append(content)
            } else {
                if inBlockquote {
                    result.append("</blockquote>")
                    inBlockquote = false
                }
                result.append(line)
            }
        }
        
        if inBlockquote {
            result.append("</blockquote>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func processTables(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // 检查是否是表格行
            if line.contains("|") && i + 1 < lines.count {
                let nextLine = lines[i + 1]
                
                // 检查是否有分隔行
                if nextLine.contains("|") && nextLine.contains("-") {
                    // 开始表格
                    result.append("<table>")
                    
                    // 处理表头
                    let headers = parseTableRow(line)
                    result.append("<thead><tr>")
                    for header in headers {
                        result.append("<th>\(header.trimmingCharacters(in: .whitespaces))</th>")
                    }
                    result.append("</tr></thead>")
                    
                    // 跳过分隔行
                    i += 2
                    
                    // 处理表格内容
                    result.append("<tbody>")
                    while i < lines.count && lines[i].contains("|") {
                        let cells = parseTableRow(lines[i])
                        result.append("<tr>")
                        for cell in cells {
                            result.append("<td>\(cell.trimmingCharacters(in: .whitespaces))</td>")
                        }
                        result.append("</tr>")
                        i += 1
                    }
                    result.append("</tbody>")
                    result.append("</table>")
                    continue
                }
            }
            
            result.append(line)
            i += 1
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func parseTableRow(_ row: String) -> [String] {
        var cells = row.components(separatedBy: "|")
        // 移除首尾空元素
        if cells.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            cells.removeFirst()
        }
        if cells.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            cells.removeLast()
        }
        return cells
    }
    
    private static func processUnorderedLists(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if (trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")) && !trimmed.hasPrefix("- [") {
                let content = String(trimmed.dropFirst(2))
                if !inList {
                    result.append("<ul>")
                    inList = true
                }
                result.append("<li>\(content)</li>")
            } else {
                if inList && !trimmed.isEmpty && !line.hasPrefix("  ") {
                    result.append("</ul>")
                    inList = false
                }
                result.append(line)
            }
        }
        
        if inList {
            result.append("</ul>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func processOrderedLists(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false
        
        let pattern = "^\\d+\\.\\s+"
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let range = trimmed.range(of: pattern, options: .regularExpression) {
                let content = String(trimmed[range.upperBound...])
                if !inList {
                    result.append("<ol>")
                    inList = true
                }
                result.append("<li>\(content)</li>")
            } else {
                if inList && !trimmed.isEmpty {
                    result.append("</ol>")
                    inList = false
                }
                result.append(line)
            }
        }
        
        if inList {
            result.append("</ol>")
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func processParagraphs(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var paragraph: [String] = []
        
        let blockTags = ["<h1", "<h2", "<h3", "<h4", "<h5", "<h6", "<ul", "</ul", "<ol", "</ol", "<li", "<blockquote", "</blockquote", "<pre", "</pre", "<table", "</table", "<thead", "</thead", "<tbody", "</tbody", "<tr", "</tr", "<th", "</th", "<td", "</td", "<hr"]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isBlockElement = blockTags.contains { trimmed.hasPrefix($0) }
            
            if trimmed.isEmpty || isBlockElement {
                if !paragraph.isEmpty {
                    result.append("<p>\(paragraph.joined(separator: " "))</p>")
                    paragraph = []
                }
                if isBlockElement {
                    result.append(line)
                }
            } else if !trimmed.hasPrefix("<") {
                paragraph.append(trimmed)
            } else {
                result.append(line)
            }
        }
        
        if !paragraph.isEmpty {
            result.append("<p>\(paragraph.joined(separator: " "))</p>")
        }
        
        return result.joined(separator: "\n")
    }
}

#Preview {
    MarkdownPreviewView()
        .frame(width: 1000, height: 700)
}
