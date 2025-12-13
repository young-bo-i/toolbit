import SwiftUI

struct CharacterCountView: View {
    @State private var inputText: String = ""
    
    private var stats: TextStats {
        TextStats(text: inputText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 输入区域
            VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                    Text("输入文本")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                Spacer()
                
                    // 实时字符计数
                    Text("\(stats.characterCount) 字符")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
            
            Divider()
                        .frame(height: 12)
                        .padding(.horizontal, 8)
                    
                    HStack(spacing: 4) {
                        Button(action: pasteText) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
                        Button(action: { inputText = "" }) {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(inputText.isEmpty)
                        .help("清空")
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
                
                // 文本输入框
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                    
                            if inputText.isEmpty {
                                Text("在此输入或粘贴文本...")
                            .font(.body)
                                    .foregroundStyle(.tertiary)
                            .padding(12)
                            .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                .frame(minHeight: 120, maxHeight: 200)
                .background(Color(nsColor: .textBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            
            // 统计结果区域
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 主要统计
                    StatSection(title: "基础统计") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            StatCard(title: "字符数", value: stats.characterCount, icon: "character", color: .blue)
                            StatCard(title: "不含空格", value: stats.characterCountNoSpaces, icon: "character.cursor.ibeam", color: .cyan)
                            StatCard(title: "单词数", value: stats.wordCount, icon: "text.word.spacing", color: .green)
                            StatCard(title: "中文字数", value: stats.chineseCharacterCount, icon: "character.book.closed.fill.zh", color: .orange)
                        }
                    }
                    
                    // 结构统计
                    StatSection(title: "结构统计") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            StatCard(title: "行数", value: stats.lineCount, icon: "text.line.first.and.arrowtriangle.forward", color: .purple)
                            StatCard(title: "段落数", value: stats.paragraphCount, icon: "paragraphsign", color: .pink)
                            StatCard(title: "句子数", value: stats.sentenceCount, icon: "text.bubble", color: .indigo)
                            StatCard(title: "数字个数", value: stats.digitCount, icon: "number", color: .mint)
                        }
                    }
                    
                    // 编码信息
                    StatSection(title: "编码信息") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            StatCard(title: "UTF-8 字节", value: stats.byteCountUTF8, icon: "memorychip", color: .red)
                            StatCard(title: "UTF-16 字节", value: stats.byteCountUTF16, icon: "memorychip.fill", color: .teal)
                        }
                    }
                        }
                .padding(20)
            }
        }
        .onDisappear {
            inputText = ""
        }
    }
    
    private func pasteText() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputText = string
        }
    }
}

// MARK: - 统计区块
struct StatSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            content
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // 文本
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            
            Spacer(minLength: 0)
            
            // 复制按钮
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(value)", forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .help("复制数值")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 统计数据模型
struct TextStats {
    let text: String
    
    var characterCount: Int { text.count }
    var characterCountNoSpaces: Int { text.filter { !$0.isWhitespace }.count }
    var wordCount: Int { text.split { $0.isWhitespace || $0.isNewline }.count }
    var chineseCharacterCount: Int { text.filter { $0.isChineseCharacter }.count }
    
    var lineCount: Int {
        if text.isEmpty { return 0 }
        return text.components(separatedBy: .newlines).count
    }
    
    var paragraphCount: Int {
        if text.isEmpty { return 0 }
        let paragraphs = text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return max(paragraphs.count, text.isEmpty ? 0 : 1)
    }
    
    var sentenceCount: Int {
        let pattern = "[.!?。！？]"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..., in: text)
        return regex?.numberOfMatches(in: text, range: range) ?? 0
    }
    
    var digitCount: Int { text.filter { $0.isNumber }.count }
    var byteCountUTF8: Int { text.utf8.count }
    var byteCountUTF16: Int { text.utf16.count * 2 }
}

extension Character {
    var isChineseCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}

#Preview {
    CharacterCountView()
        .frame(width: 900, height: 600)
}
