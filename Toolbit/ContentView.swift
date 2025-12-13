import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        ZStack(alignment: .top) {
            // 主内容
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // 侧边栏
                SidebarView(selectedTool: $selectedTool)
            } detail: {
                // 主内容区
                Group {
                    if selectedTool == .home {
                        HomeView(selectedTool: $selectedTool, searchText: searchText)
                    } else {
                        mainContent
                    }
                }
                .toolbar {
                    // 占位符（把搜索框推到右边）
                    ToolbarItem(placement: .principal) {
                        Spacer()
                    }
                    
                    // 搜索框（放在最右边，固定宽度）
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            TextField("搜索工具...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .onChange(of: searchText) { _, newValue in
                                    if !newValue.isEmpty && selectedTool != .home {
                                        selectedTool = .home
                                    }
                                }
                            
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .opacity(searchText.isEmpty ? 0 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(searchText.isEmpty)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(width: 180) // 固定整体宽度
                    }
                }
            }
            .navigationSplitViewStyle(.prominentDetail)
            
            // 更新悬浮提示（居中显示在 toolbar 区域）
            UpdateBanner()
                .padding(.top, 6)
        }
        // 不设置 minWidth，避免边界震荡
        .frame(idealWidth: 1200, minHeight: 650)
        // 启动定时检查更新（每1小时）
        .onAppear {
            if updateManager.autoCheckEnabled {
                updateManager.startPeriodicUpdateCheck()
            }
        }
        .onDisappear {
            updateManager.stopPeriodicUpdateCheck()
        }
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
