import SwiftUI

// MARK: - 颜色混合扩展
extension Color {
    /// 将当前颜色与另一个颜色混合
    /// - Parameters:
    ///   - other: 目标颜色
    ///   - ratio: 混合比例 (0-1)，0 表示完全使用当前颜色，1 表示完全使用目标颜色
    /// - Returns: 混合后的颜色
    func blend(with other: Color, ratio: Double) -> Color {
        let ratio = max(0, min(1, ratio))
        
        // 使用 NSColor 进行线性插值
        return Color(
            nsColor: NSColor(self).blended(withFraction: ratio, of: NSColor(other)) ?? NSColor(self)
        )
    }
}

