import SwiftUI

struct CharacterCountView: View {
    @State private var inputText: String = ""
    
    // 统计数据
    private var stats: TextStats {
        TextStats(text: inputText)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("字符统计")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("统计文本中的字符、单词、行数等信息")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // 清空按钮
                Button(action: { inputText = "" }) {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(inputText.isEmpty)
            }
            .padding()
            
            Divider()
            
            // 主内容区
            HStack(spacing: 20) {
                // 左侧：文本输入区
                VStack(alignment: .leading, spacing: 12) {
                    Text("输入文本")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background {
                            GlassBackground()
                        }
                        .overlay {
                            if inputText.isEmpty {
                                Text("在此输入或粘贴文本...")
                                    .foregroundStyle(.tertiary)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .frame(minWidth: 300)
                
                // 右侧：统计结果
                VStack(alignment: .leading, spacing: 12) {
                    Text("统计结果")
                        .font(.headline)
                    
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
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        GlassBackground()
                    }
                }
                .frame(minWidth: 300)
            }
            .padding()
        }
        .background {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onDisappear {
            // 切换页面时清空状态，避免内存占用
            inputText = ""
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

