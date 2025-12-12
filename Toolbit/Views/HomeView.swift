import SwiftUI

struct HomeView: View {
    @Binding var selectedTool: ToolType
    @State private var searchText: String = ""
    @State private var hoveredTool: ToolType?
    
    private var filteredTools: [ToolType] {
        let tools = ToolType.allTools
        if searchText.isEmpty {
            return tools
        }
        return tools.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedTools: [(category: ToolCategory, tools: [ToolType])] {
        ToolCategory.allCases.compactMap { category in
            let tools = filteredTools.filter { $0.category == category }
            return tools.isEmpty ? nil : (category, tools)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero 区域
                heroSection
                
                // 搜索栏
                searchBar
                    .padding(.horizontal, 40)
                    .padding(.top, -20)
                    .zIndex(1)
                
                // 工具网格
                toolsGrid
                    .padding(.horizontal, 40)
                    .padding(.top, 32)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Hero 区域
    private var heroSection: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.purple.opacity(0.1),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            
            // 装饰性圆形
            GeometryReader { geo in
                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 200, y: -100)
                
                Circle()
                    .fill(Color.purple.opacity(0.06))
                    .frame(width: 200, height: 200)
                    .offset(x: -50, y: 50)
            }
            
            VStack(spacing: 12) {
                // Logo 和标题
                HStack(spacing: 16) {
                    AppLogoView(size: 64)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Toolbit")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        
                        Text("开发者工具集")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 统计信息
                HStack(spacing: 24) {
                    StatPill(value: "\(ToolType.allTools.count)", label: "工具")
                    StatPill(value: "\(ToolCategory.allCases.count)", label: "分类")
                    StatPill(value: "∞", label: "可能")
                }
                .padding(.top, 8)
            }
            .padding(.top, 40)
        }
        .frame(height: 200)
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField("搜索工具...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .frame(maxWidth: 400)
    }
    
    // MARK: - 工具网格
    private var toolsGrid: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(groupedTools, id: \.category) { group in
                VStack(alignment: .leading, spacing: 16) {
                    // 分类标题
                    HStack(spacing: 10) {
                        Image(systemName: group.category.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Text(group.category.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(group.tools.count) 个工具")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // 工具卡片网格
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(group.tools) { tool in
                            ToolCard(
                                tool: tool,
                                isHovered: hoveredTool == tool,
                                action: { selectedTool = tool }
                            )
                            .onHover { isHovered in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hoveredTool = isHovered ? tool : nil
                                }
                            }
                        }
                    }
                }
            }
            
            // 空状态
            if filteredTools.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    
                    Text("没有找到匹配的工具")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Text("试试其他关键词")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            }
        }
    }
}

// MARK: - 统计胶囊
struct StatPill: View {
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        }
    }
}

// MARK: - 工具卡片
struct ToolCard: View {
    let tool: ToolType
    let isHovered: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tool.color.opacity(isHovered ? 0.2 : 0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: tool.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tool.color)
                }
                
                // 文字
                VStack(alignment: .leading, spacing: 3) {
                    Text(tool.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(tool.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isHovered ? tool.color.opacity(0.4) : Color(nsColor: .separatorColor).opacity(0.5),
                        lineWidth: isHovered ? 1.5 : 0.5
                    )
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: isHovered ? tool.color.opacity(0.15) : .clear,
                radius: 8,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(selectedTool: .constant(.home))
        .frame(width: 900, height: 700)
}

