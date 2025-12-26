import SwiftUI

// MARK: - 手势可视化视图（仅双指滚动可被捕获）
struct GestureVisualizationView: View {
    let scrollCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Text("触控板")
                    .font(.headline)
                Spacer()
                Text("总计 \(scrollCount) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 触控板图形
            trackpadGraphic
                .padding(.vertical, 8)
        }
    }
    
    // MARK: - 触控板图形
    private var trackpadGraphic: some View {
        ZStack {
            // 触控板外壳
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 140, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                )
            
            // 滚动区域热力图
            RoundedRectangle(cornerRadius: 12)
                .fill(scrollIntensityColor)
                .frame(width: 120, height: 80)
                .overlay(
                    VStack(spacing: 4) {
                        // 滚动图标
                        Image(systemName: "hand.draw")
                            .font(.system(size: 20))
                            .foregroundStyle(scrollCount > 0 ? .white : .secondary)
                        
                        Text("双指滚动")
                            .font(.system(size: 9))
                            .foregroundStyle(scrollCount > 0 ? .white.opacity(0.8) : .secondary)
                        
                        Text("\(scrollCount)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(scrollCount > 0 ? .white : .secondary)
                    }
                )
        }
        .frame(width: 160, height: 120)
    }
    
    private var scrollIntensityColor: Color {
        if scrollCount == 0 {
            return Color(nsColor: .controlBackgroundColor).opacity(0.5)
        }
        
        // 根据滚动次数计算颜色强度
        let intensity = min(Double(scrollCount) / 1000.0, 1.0)
        
        if intensity < 0.3 {
            return Color.blue.opacity(0.3 + intensity * 0.5)
        } else if intensity < 0.6 {
            return Color.blue.opacity(0.5).blend(with: Color.cyan.opacity(0.7), ratio: (intensity - 0.3) / 0.3)
        } else {
            return Color.cyan.opacity(0.7).blend(with: Color.green.opacity(0.8), ratio: (intensity - 0.6) / 0.4)
        }
    }
}

#Preview {
    GestureVisualizationView(scrollCount: 500)
    .padding()
    .frame(width: 200)
}
