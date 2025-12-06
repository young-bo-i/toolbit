import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = [] // 默认全部收起
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    // 过滤后的工具列表
    private var filteredTools: [ToolType] {
        if searchText.isEmpty {
            return []
        }
        let lowercasedSearch = searchText.lowercased()
        return ToolType.allCases.filter { tool in
            tool.rawValue.lowercased().contains(lowercasedSearch) ||
            tool.description.lowercased().contains(lowercasedSearch)
        }
    }
    
    // 是否显示搜索结果
    private var showSearchResults: Bool {
        !searchText.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
            
            Divider()
            
            // 工具列表
            if showSearchResults {
                searchResultsList
            } else {
                categoryList
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("开发百宝箱")
        .frame(minWidth: 220)
        .onChange(of: selectedTool) { _, newValue in
            // 确保选中工具所在的分类是展开的
            expandedCategories.insert(newValue.category)
            // 清空搜索
            searchText = ""
        }
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
                    return nil
                }
                return event
            }
        }
    }
    
    // MARK: - 搜索框
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("搜索工具... (⌘F)", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    // 按回车选择第一个搜索结果
                    if let firstResult = filteredTools.first {
                        selectedTool = firstResult
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - 搜索结果列表
    private var searchResultsList: some View {
        List(selection: $selectedTool) {
            if filteredTools.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.tertiary)
                        Text("未找到匹配的工具")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                Section("搜索结果 (\(filteredTools.count))") {
                    ForEach(filteredTools) { tool in
                        toolRow(tool: tool, highlightSearch: true)
                    }
                }
            }
        }
    }
    
    // MARK: - 分类列表
    private var categoryList: some View {
        List(selection: $selectedTool) {
            ForEach(ToolCategory.allCases) { category in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategories.contains(category) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedCategories.insert(category)
                                } else {
                                    expandedCategories.remove(category)
                                }
                            }
                        )
                    ) {
                        ForEach(category.tools) { tool in
                            toolRow(tool: tool, highlightSearch: false)
                        }
                    } label: {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                                .font(.headline)
                            Spacer()
                            Text("\(category.tools.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(.quaternary)
                                }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 工具行
    private func toolRow(tool: ToolType, highlightSearch: Bool) -> some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    if highlightSearch && !searchText.isEmpty {
                        highlightedText(tool.rawValue, highlight: searchText)
                    } else {
                        Text(tool.rawValue)
                    }
                    
                    if highlightSearch && !searchText.isEmpty {
                        highlightedText(tool.description, highlight: searchText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(tool.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: tool.icon)
                    .foregroundStyle(selectedTool == tool ? .white : .blue)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .tag(tool)
    }
    
    // MARK: - 高亮搜索文本
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else {
            return Text(text)
        }
        
        let lowercasedText = text.lowercased()
        let lowercasedHighlight = highlight.lowercased()
        
        guard let range = lowercasedText.range(of: lowercasedHighlight) else {
            return Text(text)
        }
        
        let startIndex = text.index(text.startIndex, offsetBy: lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound))
        let endIndex = text.index(startIndex, offsetBy: highlight.count)
        
        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])
        
        return Text(before) + Text(match).foregroundColor(.accentColor).bold() + Text(after)
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.characterCount))
}
