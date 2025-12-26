import SwiftUI

// MARK: - 鼠标热力图视图
struct MouseHeatmapView: View {
    let leftClickCount: Int
    let rightClickCount: Int
    let middleClickCount: Int
    let scrollCount: Int
    let otherClickCount: Int
    
    private var maxCount: Int {
        max(leftClickCount, rightClickCount, middleClickCount, scrollCount, otherClickCount, 1)
    }
    
    private var totalCount: Int {
        leftClickCount + rightClickCount + middleClickCount + scrollCount + otherClickCount
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Text("鼠标")
                    .font(.headline)
                Spacer()
                Text("总计 \(totalCount) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            
            // 左键
            MouseLeftButton()
                .fill(buttonColor(for: leftClickCount))
                .frame(width: 38, height: 45)
                .offset(x: -15, y: -35)
                .overlay(
                    MouseLeftButton()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        .offset(x: -15, y: -35)
                )
                .overlay(
                    VStack(spacing: 1) {
                        Text("左")
                            .font(.system(size: 7))
                        Text("\(leftClickCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(textColor(for: leftClickCount))
                    .offset(x: -15, y: -35)
                )
            
            // 右键
            MouseRightButton()
                .fill(buttonColor(for: rightClickCount))
                .frame(width: 38, height: 45)
                .offset(x: 15, y: -35)
                .overlay(
                    MouseRightButton()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        .offset(x: 15, y: -35)
                )
                .overlay(
                    VStack(spacing: 1) {
                        Text("右")
                            .font(.system(size: 7))
                        Text("\(rightClickCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(textColor(for: rightClickCount))
                    .offset(x: 15, y: -35)
                )
            
            // 滚轮
            RoundedRectangle(cornerRadius: 3)
                .fill(buttonColor(for: scrollCount))
                .frame(width: 12, height: 22)
                .offset(y: -35)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                        .frame(width: 12, height: 22)
                        .offset(y: -35)
                )
            
            // 滚轮数字（显示在鼠标中间）
            VStack(spacing: 1) {
                Text("滚轮")
                    .font(.system(size: 7))
                Text("\(scrollCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .offset(y: 8)
            
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
    
    // MARK: - 颜色计算
    private func buttonColor(for count: Int) -> Color {
        guard maxCount > 0 && count > 0 else {
            return Color(nsColor: .controlBackgroundColor)
        }
        let intensity = Double(count) / Double(maxCount)
        if intensity < 0.3 {
            return Color.green.opacity(0.2 + intensity * 0.3)
        } else if intensity < 0.6 {
            return Color.green.opacity(0.4).blend(with: Color.orange.opacity(0.6), ratio: (intensity - 0.3) / 0.3)
        } else {
            return Color.orange.opacity(0.6).blend(with: Color.red.opacity(0.8), ratio: (intensity - 0.6) / 0.4)
        }
    }
    
    private func textColor(for count: Int) -> Color {
        guard maxCount > 0 && count > 0 else { return .secondary }
        let intensity = Double(count) / Double(maxCount)
        return intensity > 0.5 ? .white : .primary
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
