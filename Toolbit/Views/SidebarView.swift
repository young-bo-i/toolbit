import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = Set(ToolCategory.allCases) // 默认全部展开
    
    var body: some View {
        List(selection: $selectedTool) {
            ForEach(ToolCategory.allCases) { category in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedCategories.contains(category) },
                            set: { isExpanded in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isExpanded {
                                        _ = expandedCategories.insert(category)
                                    } else {
                                        _ = expandedCategories.remove(category)
                                    }
                                }
                            }
                        )
                    ) {
                        ForEach(category.tools) { tool in
                            toolRow(tool: tool)
                        }
                    } label: {
                        categoryLabel(category: category)
                    }
                    .tint(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, maxWidth: 260)
        .onChange(of: selectedTool) { _, newValue in
            // 确保选中工具所在的分类是展开的
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = expandedCategories.insert(newValue.category)
            }
        }
    }
    
    // MARK: - 分类标签
    private func categoryLabel(category: ToolCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(category.tools.count)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - 工具行
    private func toolRow(tool: ToolType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tool.icon)
                .font(.system(size: 13))
                .foregroundStyle(selectedTool == tool ? .white : .blue)
                .frame(width: 18)
            
            Text(tool.rawValue)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 3)
        .padding(.leading, 4)
        .contentShape(Rectangle())
        .tag(tool)
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.characterCount))
}
