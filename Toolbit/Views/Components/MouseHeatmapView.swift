import SwiftUI

// MARK: - 鼠标热力图视图
struct MouseHeatmapView: View {
    let leftClickCount: Int
    let rightClickCount: Int
    let middleClickCount: Int
    let scrollCount: Int
    let otherClickCount: Int
    var showTitle: Bool = true  // 是否显示标题
    
    private var maxCount: Int {
        max(leftClickCount, rightClickCount, middleClickCount, scrollCount, otherClickCount, 1)
    }
    
    var totalCount: Int {
        leftClickCount + rightClickCount + middleClickCount + scrollCount + otherClickCount
    }
    
    // 使用与键盘相同的颜色计算器
    private var colorCalculator: MouseHeatmapColorCalculator {
        MouseHeatmapColorCalculator(maxCount: maxCount)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题（可选）
            if showTitle {
                HStack {
                    Text("鼠标")
                        .font(.headline)
                    Spacer()
                    Text("总计 \(totalCount) 次")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 鼠标图形
            mouseGraphic
        }
    }
    
    // MARK: - 鼠标图形
    private var mouseGraphic: some View {
        ZStack {
            // 鼠标外壳
            MouseShape()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 90, height: 140)
                .overlay(
                    MouseShape()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                )
            
            // 左键区域（不与滚轮重叠）
            MouseLeftButton()
                .fill(buttonColor(for: leftClickCount))
                .frame(width: 32, height: 40)
                .offset(x: -20, y: -35)
                .overlay(
                    MouseLeftButton()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        .offset(x: -20, y: -35)
                )
                .overlay(
                    VStack(spacing: 1) {
                        Text("左")
                            .font(.system(size: 7))
                        Text(formatCount(leftClickCount))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(textColor(for: leftClickCount))
                    .offset(x: -20, y: -35)
                )
            
            // 右键区域（不与滚轮重叠）
            MouseRightButton()
                .fill(buttonColor(for: rightClickCount))
                .frame(width: 32, height: 40)
                .offset(x: 20, y: -35)
                .overlay(
                    MouseRightButton()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        .offset(x: 20, y: -35)
                )
                .overlay(
                    VStack(spacing: 1) {
                        Text("右")
                            .font(.system(size: 7))
                        Text(formatCount(rightClickCount))
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(textColor(for: rightClickCount))
                    .offset(x: 20, y: -35)
                )
            
            // 滚轮（在左右键中间，稍微靠上）
            RoundedRectangle(cornerRadius: 4)
                .fill(buttonColor(for: scrollCount))
                .frame(width: 14, height: 24)
                .offset(y: -42)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.4), lineWidth: 1)
                        .frame(width: 14, height: 24)
                        .offset(y: -42)
                )
            
            // 滚轮数字（显示在鼠标中部）
            VStack(spacing: 1) {
                Text("滚轮")
                    .font(.system(size: 7))
                Text(formatCount(scrollCount))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .offset(y: 5)
            
            // 中键点击数（如果有）
            if middleClickCount > 0 {
                Text("中 \(middleClickCount)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .offset(y: 38)
            }
            
            // 其他按键指示（侧键）
            if otherClickCount > 0 {
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(buttonColor(for: otherClickCount))
                        .frame(width: 6, height: 14)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(buttonColor(for: otherClickCount))
                        .frame(width: 6, height: 14)
                }
                .offset(x: -52, y: -8)
                
                Text("\(otherClickCount)")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .offset(x: -52, y: 22)
            }
        }
        .frame(width: 120, height: 160)
    }
    
    // MARK: - 颜色计算（使用统一的颜色计算器）
    private func buttonColor(for count: Int) -> Color {
        colorCalculator.color(for: count)
    }
    
    private func textColor(for count: Int) -> Color {
        colorCalculator.textColor(for: count)
    }
    
    // MARK: - 数字格式化
    private func formatCount(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10000 {
            let k = Double(count) / 1000.0
            if k == Double(Int(k)) {
                return "\(Int(k))K"
            }
            return String(format: "%.1fK", k)
        } else {
            let w = Double(count) / 10000.0
            if w == Double(Int(w)) {
                return "\(Int(w))W"
            }
            return String(format: "%.1fW", w)
        }
    }
}

// MARK: - 鼠标热力图颜色计算器（与键盘使用相同的冷暖色阶）
struct MouseHeatmapColorCalculator {
    let maxCount: Int
    
    /// 计算强度值 (0-1)，使用对数缩放
    func intensity(for count: Int) -> Double {
        guard count > 0, maxCount > 0 else { return 0 }
        
        let logCount = log(Double(count) + 1)
        let logMax = log(Double(maxCount) + 1)
        
        guard logMax > 0 else { return 0 }
        let normalized = logCount / logMax
        
        // gamma 校正
        let gamma = 0.6
        return pow(normalized, gamma)
    }
    
    /// 获取颜色 - 冷暖色阶（蓝→红）
    func color(for count: Int) -> Color {
        guard count > 0 else {
            return Color(nsColor: .controlBackgroundColor)
        }
        
        let t = intensity(for: count)
        return interpolateColor(t: t)
    }
    
    /// 插值计算颜色 - 冷到暖色阶
    private func interpolateColor(t: Double) -> Color {
        // 冷暖色阶：深蓝 → 蓝 → 青 → 绿 → 黄 → 橙 → 红
        let colors: [(r: Double, g: Double, b: Double)] = [
            (0.192, 0.212, 0.584),  // #313595 深蓝色
            (0.270, 0.459, 0.706),  // #4575B4 蓝色
            (0.455, 0.678, 0.820),  // #74ADD1 浅蓝色
            (0.671, 0.851, 0.914),  // #ABD9E9 淡青色
            (0.878, 0.953, 0.973),  // #E0F3F8 极淡青
            (0.996, 0.878, 0.565),  // #FEE090 淡黄色
            (0.992, 0.682, 0.380),  // #FDAE61 橙黄色
            (0.957, 0.427, 0.263),  // #F46D43 橙红色
            (0.843, 0.188, 0.153),  // #D73027 红色
        ]
        
        let segment = t * Double(colors.count - 1)
        let index = min(Int(segment), colors.count - 2)
        let localT = segment - Double(index)
        
        let c1 = colors[index]
        let c2 = colors[index + 1]
        
        let r = c1.r + (c2.r - c1.r) * localT
        let g = c1.g + (c2.g - c1.g) * localT
        let b = c1.b + (c2.b - c1.b) * localT
        
        return Color(red: r, green: g, blue: b)
    }
    
    /// 文字颜色 - 根据背景亮度选择
    func textColor(for count: Int) -> Color {
        guard count > 0 else { return .secondary }
        
        let t = intensity(for: count)
        // 中间浅色区域用深色文字，两端深色区域用白色文字
        if t > 0.25 && t < 0.7 {
            return Color(white: 0.15)
        }
        return .white
    }
}

// MARK: - 鼠标形状
struct MouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // 鼠标轮廓
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.3),
            control1: CGPoint(x: w * 0.85, y: 0),
            control2: CGPoint(x: w, y: h * 0.1)
        )
        path.addLine(to: CGPoint(x: w, y: h * 0.7))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.9),
            control2: CGPoint(x: w * 0.8, y: h)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.7),
            control1: CGPoint(x: w * 0.2, y: h),
            control2: CGPoint(x: 0, y: h * 0.9)
        )
        path.addLine(to: CGPoint(x: 0, y: h * 0.3))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.1),
            control2: CGPoint(x: w * 0.15, y: 0)
        )
        
        return path
    }
}

// MARK: - 鼠标左键形状
struct MouseLeftButton: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.3))
        path.addCurve(
            to: CGPoint(x: w * 0.8, y: 0),
            control1: CGPoint(x: 0, y: 0),
            control2: CGPoint(x: w * 0.3, y: 0)
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 鼠标右键形状
struct MouseRightButton: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w, y: h * 0.3))
        path.addCurve(
            to: CGPoint(x: w * 0.2, y: 0),
            control1: CGPoint(x: w, y: 0),
            control2: CGPoint(x: w * 0.7, y: 0)
        )
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    MouseHeatmapView(
        leftClickCount: 500,
        rightClickCount: 120,
        middleClickCount: 30,
        scrollCount: 800,
        otherClickCount: 15
    )
    .padding()
    .frame(width: 160)
}
