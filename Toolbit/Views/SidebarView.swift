import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = []
    
    var body: some View {
        List(selection: $selectedTool) {
            // 工具分类
            ForEach(ToolCategory.allCases) { category in
                DisclosureGroup(
                    isExpanded: expandedBinding(for: category)
                ) {
                    ForEach(category.tools) { tool in
                        Label {
                            Text(tool.displayName)
                        } icon: {
                            Image(systemName: tool.icon)
                                .foregroundStyle(tool.color)
                        }
                        .tag(tool)
                    }
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        
                        Text(category.displayName)
                            .font(.headline)
                    }
                }
                .tint(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, maxWidth: 260)
        .onChange(of: selectedTool) { _, newValue in
            // 选中工具时展开对应分类（首页除外）
            if newValue != .home && !expandedCategories.contains(newValue.category) {
                _ = expandedCategories.insert(newValue.category)
            }
        }
    }
    
    // 创建展开状态的 Binding
    private func expandedBinding(for category: ToolCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.home))
}
