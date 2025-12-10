import SwiftUI

struct SidebarView: View {
    @Binding var selectedTool: ToolType
    @State private var expandedCategories: Set<ToolCategory> = Set(ToolCategory.allCases)
    @State private var hoveredTool: ToolType?
    @State private var hoveredCategory: ToolCategory?
    @Namespace private var animation
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(ToolCategory.allCases) { category in
                    CategorySection(
                        category: category,
                        isExpanded: expandedCategories.contains(category),
                        isHovered: hoveredCategory == category,
                        selectedTool: selectedTool,
                        hoveredTool: hoveredTool,
                        animation: animation,
                        onToggle: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if expandedCategories.contains(category) {
                                    _ = expandedCategories.remove(category)
                                } else {
                                    _ = expandedCategories.insert(category)
                                }
                            }
                        },
                        onSelectTool: { tool in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTool = tool
                            }
                        },
                        onHoverTool: { tool in
                            withAnimation(.easeOut(duration: 0.15)) {
                                hoveredTool = tool
                            }
                        },
                        onHoverCategory: { isHovered in
                            withAnimation(.easeOut(duration: 0.15)) {
                                hoveredCategory = isHovered ? category : nil
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 220, maxWidth: 280)
        .background(
            // 液态玻璃背景
            ZStack {
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                
                // 渐变叠加
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onChange(of: selectedTool) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                _ = expandedCategories.insert(newValue.category)
            }
        }
    }
}

// MARK: - 分类区块
struct CategorySection: View {
    let category: ToolCategory
    let isExpanded: Bool
    let isHovered: Bool
    let selectedTool: ToolType
    let hoveredTool: ToolType?
    var animation: Namespace.ID
    let onToggle: () -> Void
    let onSelectTool: (ToolType) -> Void
    let onHoverTool: (ToolType?) -> Void
    let onHoverCategory: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 分类标题
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    // 图标容器 - 液态玻璃效果
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(categoryGradient)
                            .frame(width: 28, height: 28)
                            .shadow(color: categoryColor.opacity(0.3), radius: isHovered ? 8 : 4, y: 2)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(isHovered ? 1.05 : 1.0)
                    
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // 工具数量徽章
                    Text("\(category.tools.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                        )
                    
                    // 展开/收起箭头
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered in
                onHoverCategory(isHovered)
            }
            
            // 子菜单项
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(category.tools) { tool in
                        ToolRow(
                            tool: tool,
                            isSelected: selectedTool == tool,
                            isHovered: hoveredTool == tool,
                            animation: animation,
                            onSelect: { onSelectTool(tool) },
                            onHover: { isHovered in
                                onHoverTool(isHovered ? tool : nil)
                            }
                        )
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -10)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.primary.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    private var categoryColor: Color {
        switch category {
        case .textTools: return .blue
        case .encoderDecoder: return .purple
        case .formatters: return .orange
        case .imageTools: return .green
        }
    }
    
    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: [categoryColor, categoryColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 工具行
struct ToolRow: View {
    let tool: ToolType
    let isSelected: Bool
    let isHovered: Bool
    var animation: Namespace.ID
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // 工具图标
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .shadow(color: .blue.opacity(0.4), radius: 6, y: 2)
                            .matchedGeometryEffect(id: "selectedIndicator", in: animation)
                    } else if isHovered {
                        Circle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: 26, height: 26)
                    }
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white : (isHovered ? .blue : .secondary))
                }
                .frame(width: 26, height: 26)
                
                // 工具名称
                Text(tool.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.15),
                                        Color.blue.opacity(0.08)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .blue.opacity(0.1), radius: 8, y: 2)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.primary.opacity(0.04))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            onHover(isHovered)
        }
        .scaleEffect(isHovered && !isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - 毛玻璃效果
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    SidebarView(selectedTool: .constant(.characterCount))
        .frame(height: 600)
}
