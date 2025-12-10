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
            // 标题 - 纯文本，无任何装饰
            ToolbarItem(placement: .navigation) {
                Text(selectedTool.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            // 搜索框 - 最右边
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    TextField("搜索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)
                        .frame(width: 120)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
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
