import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = Set(ToolCategory.allCases)
    
    var body: some View {
        List(selection: $selectedTool) {
            ForEach(ToolCategory.allCases) { category in
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
                        Label {
                            Text(tool.rawValue)
                        } icon: {
                            Image(systemName: tool.icon)
                                .foregroundStyle(.blue)
                        }
                        .tag(tool)
                    }
                } label: {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                }
                .tint(.secondary)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, maxWidth: 260)
        .onChange(of: selectedTool) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                _ = expandedCategories.insert(newValue.category)
            }
        }
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.characterCount))
}
