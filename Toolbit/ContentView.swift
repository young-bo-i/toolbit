import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .home
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(selectedTool: $selectedTool)
        } detail: {
            // 主内容区
            if selectedTool == .home {
                HomeView(selectedTool: $selectedTool)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // 标题栏
                    HStack {
                        Text(selectedTool.displayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    
                    // 主内容
                    mainContent
                }
            }
        }
        // MARK: - 自定义顶部工具栏（无边框标题 + 有边框按钮）
        // 使用方法：.customToolbar(title: "标题文案") { /* 按钮点击事件 */ }
        // .customToolbar(title: "测试文案") {
        //     openWindow(id: "about")
        // }
        .frame(minWidth: 1000, minHeight: 650)
    }
    
    // MARK: - 主内容
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch selectedTool {
            case .home:
                EmptyView()
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
