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
            // 标题放在工具栏左侧
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
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 650)
        // 全局快捷键 Command+F 聚焦搜索框
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "f" {
                    isSearchFocused = true
                    return nil
                }
                // ESC 清空搜索
                if event.keyCode == 53 && !searchText.isEmpty {
                    searchText = ""
                    isSearchFocused = false
                    return nil
                }
                return event
            }
        }
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
        .id(selectedTool) // 切换工具时强制重建视图，清空状态
    }
}

#Preview {
    ContentView()
}
