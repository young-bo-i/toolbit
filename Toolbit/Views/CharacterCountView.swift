import SwiftUI

struct CharacterCountView: View {
    @State private var inputText: String = ""
    
    // 统计数据
    private var stats: TextStats {
        TextStats(text: inputText)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧：文本输入区
            VStack(alignment: .leading, spacing: 0) {
                // 输入区标题栏
                HStack {
                    Text("输入文本")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 8) {
                        Button(action: pasteText) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                        .help("粘贴")
                        
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
                
                // 文本输入
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled(true)
                    .padding(12)
                    .overlay {
                        if inputText.isEmpty {
                            Text("在此输入或粘贴文本...")
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(16)
                        }
                    }
            }
            .frame(minWidth: 300)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
            
            Divider()
            
            // 右侧：统计结果
            VStack(alignment: .leading, spacing: 0) {
                // 结果标题栏
                HStack {
                    Text("统计结果")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                Divider()
                
                // 统计卡片
                ScrollView {
                    VStack(spacing: 12) {
                        StatCardRow(items: [
                            StatItem(title: "字符数", value: "\(stats.characterCount)", icon: "character", color: .blue),
                            StatItem(title: "字符数(不含空格)", value: "\(stats.characterCountNoSpaces)", icon: "character.cursor.ibeam", color: .cyan)
                        ])
                        
                        StatCardRow(items: [
                            StatItem(title: "单词数", value: "\(stats.wordCount)", icon: "text.word.spacing", color: .green),
                            StatItem(title: "中文字数", value: "\(stats.chineseCharacterCount)", icon: "character.book.closed.fill.zh", color: .orange)
                        ])
                        
                        StatCardRow(items: [
                            StatItem(title: "行数", value: "\(stats.lineCount)", icon: "text.line.first.and.arrowtriangle.forward", color: .purple),
                            StatItem(title: "段落数", value: "\(stats.paragraphCount)", icon: "paragraphsign", color: .pink)
                        ])
                        
                        StatCardRow(items: [
                            StatItem(title: "句子数", value: "\(stats.sentenceCount)", icon: "text.bubble", color: .indigo),
                            StatItem(title: "数字个数", value: "\(stats.digitCount)", icon: "number", color: .mint)
                        ])
                        
                        StatCardRow(items: [
                            StatItem(title: "字节数(UTF-8)", value: "\(stats.byteCountUTF8)", icon: "memorychip", color: .red),
                            StatItem(title: "字节数(UTF-16)", value: "\(stats.byteCountUTF16)", icon: "memorychip.fill", color: .teal)
                        ])
                    }
                    .padding(16)
                }
            }
            .frame(minWidth: 350)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
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

// MARK: - 统计数据模型
struct TextStats {
    let text: String
    
    var characterCount: Int {
        text.count
    }
    
    var characterCountNoSpaces: Int {
        text.filter { !$0.isWhitespace }.count
    }
    
    var wordCount: Int {
        let words = text.split { $0.isWhitespace || $0.isNewline }
        return words.count
    }
    
    var chineseCharacterCount: Int {
        text.filter { $0.isChineseCharacter }.count
    }
    
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
    
    var digitCount: Int {
        text.filter { $0.isNumber }.count
    }
    
    var byteCountUTF8: Int {
        text.utf8.count
    }
    
    var byteCountUTF16: Int {
        text.utf16.count * 2
    }
}

extension Character {
    var isChineseCharacter: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // CJK统一汉字范围
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}

// MARK: - 统计卡片组件
struct StatItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
}

struct StatCardRow: View {
    let items: [StatItem]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(items) { item in
                StatCard(item: item)
            }
        }
    }
}

struct StatCard: View {
    let item: StatItem
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(item.color)
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(item.color.opacity(0.15))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
    }
}

// MARK: - 液态玻璃背景组件
struct GlassBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
    }
}

#Preview {
    CharacterCountView()
        .frame(width: 800, height: 600)
}
