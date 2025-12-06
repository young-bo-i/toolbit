import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .characterCount
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            SidebarView(selectedTool: $selectedTool)
        } detail: {
            // 主内容区 - 使用 id 强制在切换时重新创建视图
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
        .frame(minWidth: 1000, minHeight: 650)
    }
}

#Preview {
    ContentView()
}
