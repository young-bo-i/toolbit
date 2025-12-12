import SwiftUI
import AppKit

// MARK: - 统一样式常量
struct AppStyle {
    static let panelPadding: CGFloat = 16
    static let headerPadding: CGFloat = 12
    static let contentSpacing: CGFloat = 12
    static let buttonSpacing: CGFloat = 8
    static let panelCornerRadius: CGFloat = 10
    static let inputCornerRadius: CGFloat = 8
    static let minPanelWidth: CGFloat = 320
}

// MARK: - 文本输入区域
struct TextInputArea: View {
    @Binding var text: String
    let placeholder: String
    var useMonospacedFont: Bool = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(useMonospacedFont ? .system(.body, design: .monospaced) : .body)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled(true)
                .padding(12)
            
            if text.isEmpty {
                Text(placeholder)
                    .font(useMonospacedFont ? .system(.body, design: .monospaced) : .body)
                    .foregroundStyle(.tertiary)
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 结果显示区域
struct ResultDisplayArea: View {
    let text: String
    let placeholder: String
    var error: String? = nil
    var useMonospacedFont: Bool = true
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if text.isEmpty {
                Text(placeholder)
                    .font(useMonospacedFont ? .system(.body, design: .monospaced) : .body)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            } else {
                ScrollView {
                    Text(text)
                        .font(useMonospacedFont ? .system(.body, design: .monospaced) : .body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 错误提示栏
struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, AppStyle.panelPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 字符计数标签
struct CharacterCountLabel: View {
    let count: Int
    
    var body: some View {
        Text("\(count) 字符")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - 信息标签
struct InfoBadge: View {
    let text: String
    var color: Color = .accentColor
    
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(color.opacity(0.1))
            }
    }
}

// MARK: - 代码编辑器
/// 代码编辑器 - 禁用智能引号和自动替换功能
struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    var isEditable: Bool = true
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        // 禁用智能引号和自动替换
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        
        // 基本设置
        textView.font = font
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        
        // 外观设置
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // 设置代理
        textView.delegate = context.coordinator
        
        // 滚动视图设置
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // 只在文本不同时更新，避免光标跳动
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
        
        textView.font = font
        textView.isEditable = isEditable
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        
        init(_ parent: CodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - 预览
#Preview {
    CodeEditor(text: .constant("{\n  \"name\": \"test\",\n  \"value\": 123\n}"))
        .frame(width: 400, height: 300)
        .padding()
        .background(Color.gray.opacity(0.2))
}

