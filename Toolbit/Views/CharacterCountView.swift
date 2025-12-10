import SwiftUI

struct CharacterCountView: View {
    @State private var inputText: String = ""
    
    // 统计数据 - 使用计算属性避免不必要的重算
    private var stats: TextStats {
        TextStats(text: inputText)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：文本输入区
            inputPanel
            
            // 右侧：统计结果
            statsPanel
        }
        .padding(16)
        .onDisappear {
            inputText = ""
        }
    }
    
    // MARK: - 输入面板
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Label("输入文本", systemImage: "text.alignleft")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 8) {
                    Button(action: pasteText) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .help("粘贴")
                    
                    Button(action: { inputText = "" }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.borderless)
                    .disabled(inputText.isEmpty)
                    .help("清空")
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 文本输入
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled(true)
                    .padding(12)
                
                if inputText.isEmpty {
                    Text("在此输入或粘贴文本进行统计...")
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 320)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }
    
    // MARK: - 统计面板
    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Label("统计结果", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 实时字数显示
                Text("\(stats.characterCount) 字")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(.blue.opacity(0.1))
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 统计卡片网格
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    StatCard(title: "字符数", value: stats.characterCount, icon: "character", color: .blue)
                    StatCard(title: "不含空格", value: stats.characterCountNoSpaces, icon: "character.cursor.ibeam", color: .cyan)
                    StatCard(title: "单词数", value: stats.wordCount, icon: "text.word.spacing", color: .green)
                    StatCard(title: "中文字数", value: stats.chineseCharacterCount, icon: "character.book.closed.fill.zh", color: .orange)
                    StatCard(title: "行数", value: stats.lineCount, icon: "text.line.first.and.arrowtriangle.forward", color: .purple)
                    StatCard(title: "段落数", value: stats.paragraphCount, icon: "paragraphsign", color: .pink)
                    StatCard(title: "句子数", value: stats.sentenceCount, icon: "text.bubble", color: .indigo)
                    StatCard(title: "数字个数", value: stats.digitCount, icon: "number", color: .mint)
                    StatCard(title: "UTF-8 字节", value: stats.byteCountUTF8, icon: "memorychip", color: .red)
                    StatCard(title: "UTF-16 字节", value: stats.byteCountUTF16, icon: "memorychip.fill", color: .teal)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 360)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }
    
    private func pasteText() {
        if let string = NSPasteboard.general.string(forType: .string) {
            inputText = string
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
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(isHovered ? 0.2 : 0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.thinMaterial)
                .shadow(color: color.opacity(isHovered ? 0.12 : 0), radius: 6, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(isHovered ? 0.3 : 0), lineWidth: 1)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
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
        return (0x4E00...0x9FFF).contains(scalar.value) ||
               (0x3400...0x4DBF).contains(scalar.value) ||
               (0x20000...0x2A6DF).contains(scalar.value)
    }
}

#Preview {
    CharacterCountView()
        .frame(width: 800, height: 600)
}
