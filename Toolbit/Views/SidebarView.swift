import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = []
    
    var body: some View {
        List(selection: $selectedTool) {
            ForEach(ToolCategory.allCases) { category in
                DisclosureGroup(
                    isExpanded: expandedBinding(for: category)
                ) {
                    ForEach(category.tools) { tool in
                        Label {
                            Text(tool.displayName)
                        } icon: {
                            Image(systemName: tool.icon)
                                .foregroundStyle(.blue)
                        }
                        .tag(tool)
                    }
                } label: {
                    Text(category.displayName)
                        .font(.system(size: 13, weight: .semibold))
                }
                .tint(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, maxWidth: 260)
        .onChange(of: selectedTool) { _, newValue in
            // 选中工具时展开对应分类，使用轻量动画
            if !expandedCategories.contains(newValue.category) {
                withAnimation(.easeOut(duration: 0.15)) {
                    expandedCategories.insert(newValue.category)
                }
            }
        }
    }
    
    // 创建展开状态的 Binding，避免在 set 中使用动画
    private func expandedBinding(for category: ToolCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                // 不在这里使用 withAnimation，让系统处理默认动画
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
    SidebarView(selectedTool: .constant(.characterCount))
}
