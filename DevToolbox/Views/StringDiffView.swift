import SwiftUI
import Combine

struct StringDiffView: View {
    @State private var leftText: String = ""
    @State private var rightText: String = ""
    @State private var diffResult: [DiffLine] = []
    @State private var showOnlyChanges: Bool = false
    @State private var isComparing: Bool = false
    
    // 用于防抖的任务
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
            // 标题栏
            headerView
            
            Divider()
            
            // 主内容区
            HSplitView {
                // 左侧输入区
                inputPanel(
                    title: "原始文本",
                    text: $leftText,
                    placeholder: "输入或粘贴原始文本..."
                )
                
                // 右侧输入区
                inputPanel(
                    title: "新文本",
                    text: $rightText,
                    placeholder: "输入或粘贴新文本..."
                )
            }
            .frame(height: 200)
            
            Divider()
            
            // 对比结果区
            VStack(spacing: 0) {
                // 结果标题栏
                HStack {
                    Text("对比结果")
                        .font(.headline)
                    
                    if isComparing {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    // 统计信息
                    if !diffResult.isEmpty {
                        statsView
                    }
                    
                    Toggle("仅显示差异", isOn: $showOnlyChanges)
                        .toggleStyle(.checkbox)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                
                // 差异视图
                if leftText.isEmpty && rightText.isEmpty {
                    emptyResultView
                } else {
                    diffResultView
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // 监听文本变化，自动触发对比
        .onChange(of: leftText) { _, _ in
            triggerDebouncedDiff()
        }
        .onChange(of: rightText) { _, _ in
            triggerDebouncedDiff()
        }
    }
    
    // MARK: - 防抖触发对比
    private func triggerDebouncedDiff() {
        // 取消之前的任务
        debounceTask?.cancel()
        
        // 创建新的延迟任务（300ms 防抖）
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            if !Task.isCancelled {
                await MainActor.run {
                    performDiff()
                }
            }
        }
    }
    
    // MARK: - 子视图
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("字符串对比")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("对比两段文本的差异，支持行级和字符级高亮")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: swapTexts) {
                    Label("交换", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .disabled(leftText.isEmpty && rightText.isEmpty)
                
                Button(action: clearAll) {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(leftText.isEmpty && rightText.isEmpty)
            }
        }
        .padding()
    }
    
    private func inputPanel(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(text.wrappedValue.count) 字符")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled(true)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
    
    private var statsView: some View {
        HStack(spacing: 16) {
            StatBadge(count: stats.addedLines, label: "新增", color: .green)
            StatBadge(count: stats.deletedLines, label: "删除", color: .red)
            StatBadge(count: stats.modifiedLines, label: "修改", color: .orange)
            StatBadge(count: stats.unchangedLines, label: "相同", color: .gray)
        }
    }
    
    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("在上方输入文本，将自动进行对比")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GlassBackground()
                .padding()
        }
    }
    
    private var diffResultView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredDiffResult) { line in
                    DiffLineView(line: line)
                }
            }
            .padding()
        }
        .background {
            GlassBackground()
                .padding()
        }
    }
    
    // MARK: - 操作方法
    
    private func performDiff() {
        isComparing = true
        
        // 异步计算避免 UI 卡顿
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
        // 交换后会自动触发 onChange，无需手动调用 performDiff
    }
    
    private func clearAll() {
        leftText = ""
        rightText = ""
        diffResult = []
    }
}

// MARK: - 统计徽章
struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
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
            lineNumberView(line.leftLineNumber)
                .frame(width: 50)
            
            // 左侧内容
            leftContentView
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 分隔符
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)
            
            // 右侧行号
            lineNumberView(line.rightLineNumber)
                .frame(width: 50)
            
            // 右侧内容
            rightContentView
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(.body, design: .monospaced))
        .background(backgroundColor)
    }
    
    private func lineNumberView(_ number: Int?) -> some View {
        Text(number.map { String($0) } ?? "")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .background(Color.gray.opacity(0.1))
    }
    
    @ViewBuilder
    private var leftContentView: some View {
        switch line.type {
        case .equal:
            Text(line.leftText ?? "")
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        case .delete:
            HStack(spacing: 4) {
                Text("-")
                    .foregroundStyle(.red)
                Text(line.leftText ?? "")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        case .insert:
            Text("")
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        case .modified:
            if let changes = line.inlineChanges {
                HStack(spacing: 0) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .padding(.leading, 8)
                    InlineChangesView(changes: changes, showDeleted: true)
                        .padding(.trailing, 8)
                }
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                    Text(line.leftText ?? "")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
    }
    
    @ViewBuilder
    private var rightContentView: some View {
        switch line.type {
        case .equal:
            Text(line.rightText ?? "")
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        case .delete:
            Text("")
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
        case .insert:
            HStack(spacing: 4) {
                Text("+")
                    .foregroundStyle(.green)
                Text(line.rightText ?? "")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
        case .modified:
            if let changes = line.inlineChanges {
                HStack(spacing: 0) {
                    Text("~")
                        .foregroundStyle(.orange)
                        .padding(.leading, 8)
                    InlineChangesView(changes: changes, showDeleted: false)
                        .padding(.trailing, 8)
                }
                .padding(.vertical, 2)
            } else {
                HStack(spacing: 4) {
                    Text("~")
                        .foregroundStyle(.orange)
                    Text(line.rightText ?? "")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
        }
    }
    
    private var backgroundColor: Color {
        switch line.type {
        case .equal:
            return .clear
        case .delete:
            return .red.opacity(0.1)
        case .insert:
            return .green.opacity(0.1)
        case .modified:
            return .orange.opacity(0.1)
        }
    }
}

// MARK: - 行内变更视图
struct InlineChangesView: View {
    let changes: [InlineChange]
    let showDeleted: Bool // true 显示删除部分，false 显示新增部分
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(changes) { change in
                switch change.type {
                case .equal:
                    Text(change.text)
                case .delete:
                    if showDeleted {
                        Text(change.text)
                            .background(Color.red.opacity(0.3))
                            .strikethrough(true, color: .red)
                    }
                case .insert:
                    if !showDeleted {
                        Text(change.text)
                            .background(Color.green.opacity(0.3))
                    }
                case .modified:
                    Text(change.text)
                        .background(Color.orange.opacity(0.3))
                }
            }
        }
    }
}

#Preview {
    StringDiffView()
        .frame(width: 900, height: 700)
}

