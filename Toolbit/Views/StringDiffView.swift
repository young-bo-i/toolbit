import SwiftUI
import Combine

struct StringDiffView: View {
    @State private var leftText: String = ""
    @State private var rightText: String = ""
    @State private var diffResult: [DiffLine] = []
    @State private var showOnlyChanges: Bool = false
    @State private var isComparing: Bool = false
    @State private var debounceTask: Task<Void, Never>?
    
    private var stats: DiffStats {
        DiffStats(from: diffResult)
    }
    
    private var filteredDiffResult: [DiffLine] {
        if showOnlyChanges {
            return diffResult.filter { $0.type != .equal }
        }
        return diffResult
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 输入区域 - 左右两栏
            HStack(spacing: 1) {
                // 左侧：原始文本
                textInputPanel(
                    title: "原始文本",
                    text: $leftText,
                    placeholder: "输入或粘贴原始文本...",
                    lineColor: .red
                )
                
                // 分隔线
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
                
                // 右侧：新文本
                textInputPanel(
                    title: "新文本",
                    text: $rightText,
                    placeholder: "输入或粘贴新文本...",
                    lineColor: .green
                )
            }
            .frame(height: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            
            // 工具栏
            HStack(spacing: 16) {
                // 统计信息
                if !diffResult.isEmpty {
                    HStack(spacing: 12) {
                        DiffStatBadge(count: stats.addedLines, label: "新增", color: .green)
                        DiffStatBadge(count: stats.deletedLines, label: "删除", color: .red)
                        DiffStatBadge(count: stats.modifiedLines, label: "修改", color: .orange)
                        DiffStatBadge(count: stats.unchangedLines, label: "相同", color: .secondary)
                    }
                }
                
                Spacer()
                
                if isComparing {
                    ProgressView()
                        .scaleEffect(0.5)
                }
                
                Toggle("仅显示差异", isOn: $showOnlyChanges)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                
                Divider()
                    .frame(height: 12)
                
                HStack(spacing: 4) {
                    Button(action: swapTexts) {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                    .buttonStyle(.borderless)
                    .disabled(leftText.isEmpty && rightText.isEmpty)
                    .help("交换文本")
                    
                    Button(action: clearAll) {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(leftText.isEmpty && rightText.isEmpty)
                    .help("清空全部")
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // 对比结果区域
            VStack(spacing: 0) {
                if leftText.isEmpty && rightText.isEmpty {
                    // 空状态
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("在上方输入文本，将自动进行对比")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredDiffResult.isEmpty && showOnlyChanges {
                    // 没有差异
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        Text("两段文本完全相同")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 差异结果
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredDiffResult) { line in
                                DiffLineView(line: line)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onChange(of: leftText) { _, _ in triggerDebouncedDiff() }
        .onChange(of: rightText) { _, _ in triggerDebouncedDiff() }
        .onDisappear {
            debounceTask?.cancel()
            debounceTask = nil
            leftText = ""
            rightText = ""
            diffResult = []
        }
    }
    
    // MARK: - 文本输入面板
    private func textInputPanel(title: String, text: Binding<String>, placeholder: String, lineColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                // 颜色指示条
                RoundedRectangle(cornerRadius: 1)
                    .fill(lineColor)
                    .frame(width: 3, height: 14)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                
                Button(action: {
                    if let string = NSPasteboard.general.string(forType: .string) {
                        text.wrappedValue = string
                    }
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("粘贴")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // 文本编辑区
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(8)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - 操作方法
    
    private func triggerDebouncedDiff() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run { performDiff() }
            }
        }
    }
    
    private func performDiff() {
        isComparing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DiffEngine.computeLineDiff(oldText: leftText, newText: rightText)
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    diffResult = result
                }
                isComparing = false
            }
        }
    }
    
    private func swapTexts() {
        let temp = leftText
        leftText = rightText
        rightText = temp
    }
    
    private func clearAll() {
        leftText = ""
        rightText = ""
        diffResult = []
    }
}

// MARK: - 统计徽章
struct DiffStatBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text("\(count)")
                .fontWeight(.medium)
                .monospacedDigit()
            
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

// MARK: - 单行差异视图
struct DiffLineView: View {
    let line: DiffLine
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧行号
            Text(line.leftLineNumber.map { String($0) } ?? "")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            
            // 左侧内容
            leftContentView
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 中间分隔
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .padding(.vertical, 2)
            
            // 右侧行号
            Text(line.rightLineNumber.map { String($0) } ?? "")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)
            
            // 右侧内容
            rightContentView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 1)
        .background(backgroundColor)
    }
    
    @ViewBuilder
    private var leftContentView: some View {
        switch line.type {
        case .equal:
            Text(line.leftText ?? "")
                .foregroundStyle(.primary)
        case .delete:
            HStack(spacing: 4) {
                Text("-")
                    .foregroundStyle(.red)
                    .fontWeight(.bold)
                Text(line.leftText ?? "")
            }
        case .insert:
            Text("")
        case .modified:
            if let changes = line.inlineChanges {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    InlineChangesView(changes: changes, showDeleted: true)
                }
            } else {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    Text(line.leftText ?? "")
                }
            }
        }
    }
    
    @ViewBuilder
    private var rightContentView: some View {
        switch line.type {
        case .equal:
            Text(line.rightText ?? "")
                .foregroundStyle(.primary)
        case .delete:
            Text("")
        case .insert:
            HStack(spacing: 4) {
                Text("+")
                    .foregroundStyle(.green)
                    .fontWeight(.bold)
                Text(line.rightText ?? "")
            }
        case .modified:
            if let changes = line.inlineChanges {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    InlineChangesView(changes: changes, showDeleted: false)
                }
            } else {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .fontWeight(.bold)
                    Text(line.rightText ?? "")
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        switch line.type {
        case .equal: return .clear
        case .delete: return .red.opacity(0.08)
        case .insert: return .green.opacity(0.08)
        case .modified: return .orange.opacity(0.08)
        }
    }
}

// MARK: - 行内变更视图
struct InlineChangesView: View {
    let changes: [InlineChange]
    let showDeleted: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(changes) { change in
                switch change.type {
                case .equal:
                    Text(change.text)
                case .delete:
                    if showDeleted {
                        Text(change.text)
                            .background(Color.red.opacity(0.25))
                            .strikethrough(true, color: .red)
                    }
                case .insert:
                    if !showDeleted {
                        Text(change.text)
                            .background(Color.green.opacity(0.25))
                    }
                case .modified:
                    Text(change.text)
                        .background(Color.orange.opacity(0.25))
                }
            }
        }
    }
}

#Preview {
    StringDiffView()
        .frame(width: 1000, height: 700)
}
