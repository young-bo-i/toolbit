import SwiftUI

struct CharacterCountView: View {
    @State private var inputText: String = ""
    @State private var isHoveringPaste = false
    @State private var isHoveringClear = false
    
    // 统计数据
    private var stats: TextStats {
        TextStats(text: inputText)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：文本输入区
            VStack(alignment: .leading, spacing: 0) {
                // 输入区标题栏
                HStack {
                    Label("输入文本", systemImage: "text.alignleft")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 6) {
                        GlassButton(
                            icon: "doc.on.clipboard",
                            label: "粘贴",
                            isHovering: $isHoveringPaste
                        ) {
                            pasteText()
                        }
                        
                        GlassButton(
                            icon: "trash",
                            label: "清空",
                            isHovering: $isHoveringClear,
                            isDisabled: inputText.isEmpty
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                inputText = ""
                            }
                        }
                    }
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(minWidth: 320)
            .background {
                GlassPanel()
            }
            
            // 右侧：统计结果
            VStack(alignment: .leading, spacing: 0) {
                // 结果标题栏
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
                        GlassStatCard(
                            title: "字符数",
                            value: stats.characterCount,
                            icon: "character",
                            color: .blue
                        )
                        
                        GlassStatCard(
                            title: "不含空格",
                            value: stats.characterCountNoSpaces,
                            icon: "character.cursor.ibeam",
                            color: .cyan
                        )
                        
                        GlassStatCard(
                            title: "单词数",
                            value: stats.wordCount,
                            icon: "text.word.spacing",
                            color: .green
                        )
                        
                        GlassStatCard(
                            title: "中文字数",
                            value: stats.chineseCharacterCount,
                            icon: "character.book.closed.fill.zh",
                            color: .orange
                        )
                        
                        GlassStatCard(
                            title: "行数",
                            value: stats.lineCount,
                            icon: "text.line.first.and.arrowtriangle.forward",
                            color: .purple
                        )
                        
                        GlassStatCard(
                            title: "段落数",
                            value: stats.paragraphCount,
                            icon: "paragraphsign",
                            color: .pink
                        )
                        
                        GlassStatCard(
                            title: "句子数",
                            value: stats.sentenceCount,
                            icon: "text.bubble",
                            color: .indigo
                        )
                        
                        GlassStatCard(
                            title: "数字个数",
                            value: stats.digitCount,
                            icon: "number",
                            color: .mint
                        )
                        
                        GlassStatCard(
                            title: "UTF-8 字节",
                            value: stats.byteCountUTF8,
                            icon: "memorychip",
                            color: .red
                        )
                        
                        GlassStatCard(
                            title: "UTF-16 字节",
                            value: stats.byteCountUTF16,
                            icon: "memorychip.fill",
                            color: .teal
                        )
                    }
                    .padding(16)
                }
            }
            .frame(minWidth: 360)
            .background {
                GlassPanel()
            }
        }
        .padding(16)
        .background {
            // 渐变背景
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .onDisappear {
            inputText = ""
        }
    }
    
    private func pasteText() {
        if let string = NSPasteboard.general.string(forType: .string) {
            withAnimation(.spring(response: 0.3)) {
                inputText = string
            }
        }
    }
}

// MARK: - 液态玻璃面板
struct GlassPanel: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - 液态玻璃按钮
struct GlassButton: View {
    let icon: String
    let label: String
    @Binding var isHovering: Bool
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDisabled ? .tertiary : (isHovering ? .primary : .secondary))
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering && !isDisabled ? .white.opacity(0.15) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(isHovering && !isDisabled ? 0.2 : 0), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .scaleEffect(isHovering && !isDisabled ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
    }
}

// MARK: - 液态玻璃统计卡片
struct GlassStatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                    .contentTransition(.numericText())
            }
            
            Spacer()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(isHovering ? 0.15 : 0.05), radius: isHovering ? 8 : 4, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isHovering ? 0.4 : 0.2),
                            .white.opacity(isHovering ? 0.2 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
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
