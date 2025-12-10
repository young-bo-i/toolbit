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
            VStack(spacing: 0) {
                // 顶部工具栏
                topToolbar
                
                Divider()
                
                // 主视图
                mainContent
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
    
    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        HStack(spacing: 16) {
            // 左侧：标题和描述
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTool.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // 右侧：工具特定按钮 + 搜索框
            HStack(spacing: 12) {
                // 工具特定的按钮区域（由各视图提供）
                toolSpecificButtons
                
                Divider()
                    .frame(height: 24)
                
                // 搜索框
                searchField
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - 搜索框
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            
            TextField("搜索...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
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
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)
        }
    }
    
    // MARK: - 工具特定按钮
    @ViewBuilder
    private var toolSpecificButtons: some View {
        // 这里可以根据 selectedTool 显示不同的按钮
        // 目前先留空，让各视图自己处理
        EmptyView()
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
