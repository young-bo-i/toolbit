import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .characterCount
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(selectedTool: $selectedTool)
        } detail: {
            // 主内容区
            mainContent
        }
        .toolbar {
            // 标题放在工具栏左侧 - 纯文本无背景
            ToolbarItem(placement: .navigation) {
                Text(selectedTool.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            
            // 搜索框放在工具栏右侧
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)
                        .frame(width: 100)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
    }
    
    // MARK: - 主内容
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch selectedTool {
            case .characterCount:
                CharacterCountView()
            case .stringDiff:
                StringDiffView()
            case .escape:
                EscapeView()
            case .markdownPreview:
                MarkdownPreviewView()
            case .base64Text:
                Base64TextView()
            case .urlCoder:
                URLCoderView()
            case .qrCode:
                QRCodeView()
            case .svgConverter:
                SVGConverterView()
            case .base64Image:
                Base64ImageView()
            case .jsonFormatter:
                JSONFormatterView()
            case .sqlFormatter:
                SQLFormatterView()
            case .xmlFormatter:
                XMLFormatterView()
            case .ocr:
                OCRView()
            }
        }
        .id(selectedTool)
    }
}

#Preview {
    ContentView()
}
