import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolType = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var searchText: String = ""
    @State private var showSearchResults: Bool = false
    @State private var selectedSearchIndex: Int = 0
    @StateObject private var updateManager = UpdateManager.shared
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @FocusState private var isSearchFocused: Bool
    
    // 搜索结果
    private var searchResults: [ToolType] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return ToolType.allCases.filter { tool in
            tool != .home && (
                tool.displayName.lowercased().contains(query) ||
                tool.subtitle.lowercased().contains(query)
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 主内容
            NavigationSplitView(columnVisibility: $columnVisibility) {
                // 侧边栏
                SidebarView(selectedTool: $selectedTool)
            } detail: {
                // 主内容区
                Group {
                    if selectedTool == .home {
                        HomeView(selectedTool: $selectedTool, searchText: "")
                    } else {
                        mainContent
                    }
                }
                .toolbar {
                    // 设置按钮（放在展开收起按钮右边）
                    ToolbarItem(placement: .navigation) {
                        Button(action: {
                            openSettings()
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 13))
                        }
                        .help("设置 (⌘,)")
                    }
                    
                    // 占位符（把搜索框推到右边）
                    ToolbarItem(placement: .principal) {
                        Spacer()
                    }
                    
                    // 搜索框（放在最右边，固定宽度，透明背景）
                    ToolbarItem(placement: .primaryAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            TextField("搜索工具...", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .focused($isSearchFocused)
                                .onSubmit {
                                    // 回车选中当前项
                                    if !searchResults.isEmpty && selectedSearchIndex < searchResults.count {
                                        selectTool(searchResults[selectedSearchIndex])
                                    }
                                }
                                .onChange(of: searchText) { _, newValue in
                                    showSearchResults = !newValue.isEmpty
                                    selectedSearchIndex = 0
                                }
                                .onChange(of: isSearchFocused) { _, focused in
                                    if !focused {
                                        // 延迟隐藏，让点击事件有时间触发
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            showSearchResults = false
                                        }
                                    }
                                }
                            
                            Button(action: {
                                searchText = ""
                                showSearchResults = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                    .opacity(searchText.isEmpty ? 0 : 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(searchText.isEmpty)
                        }
                        .padding(.horizontal, 4)
                        .frame(width: 220)
                        // 不添加背景，使用 toolbar 自带的外框样式
                        .onKeyPress(.downArrow) {
                            if !searchResults.isEmpty {
                                selectedSearchIndex = min(selectedSearchIndex + 1, searchResults.count - 1)
                            }
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            if !searchResults.isEmpty {
                                selectedSearchIndex = max(selectedSearchIndex - 1, 0)
                            }
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            searchText = ""
                            showSearchResults = false
                            isSearchFocused = false
                            return .handled
                        }
                        // 搜索结果下拉框（使用 overlay 自动对齐到搜索框下方）
                        .overlay(alignment: .top) {
                            if showSearchResults && !searchResults.isEmpty {
                                SearchResultsDropdown(
                                    results: searchResults,
                                    selectedIndex: $selectedSearchIndex,
                                    onSelect: selectTool
                                )
                                .frame(width: 220)
                                .offset(y: 28) // 向下偏移，宽度与搜索框一致
                            }
                        }
                    }
                }
            }
            .navigationSplitViewStyle(.prominentDetail)
            
            
            // 更新悬浮提示（居中显示在 toolbar 区域）
            UpdateBanner()
                .frame(maxWidth: .infinity)
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
    
    // MARK: - 选择工具
    private func selectTool(_ tool: ToolType) {
        selectedTool = tool
        searchText = ""
        showSearchResults = false
        isSearchFocused = false
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

// MARK: - 搜索结果下拉框
struct SearchResultsDropdown: View {
    let results: [ToolType]
    @Binding var selectedIndex: Int
    let onSelect: (ToolType) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(results.enumerated()), id: \.element) { index, tool in
                SearchResultRow(
                    tool: tool,
                    isSelected: index == selectedIndex
                )
                .onTapGesture {
                    onSelect(tool)
                }
                .onHover { hovering in
                    if hovering {
                        selectedIndex = index
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let tool: ToolType
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: tool.icon)
                .font(.system(size: 16))
                .foregroundStyle(tool.color)
                .frame(width: 24)
            
            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                
                Text(tool.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 分类标签
            Text(tool.category.displayName)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .padding(.horizontal, 6)
    }
}

#Preview {
    ContentView()
}
