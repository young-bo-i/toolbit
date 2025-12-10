import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = []
    
    var body: some View {
        List(selection: $selectedTool) {
            ForEach(ToolCategory.allCases) { category in
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
            expandedCategories.insert(newValue.category)
        }
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.characterCount))
}
