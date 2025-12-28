import SwiftUI

// MARK: - 键盘热力图视图
struct KeyboardHeatmapView: View {
    let keyStats: [Int16: Int]
    
    // 计算最大按键次数用于颜色映射
    private var maxCount: Int {
        keyStats.values.max() ?? 1
    }
    
    // 总按键次数
    private var totalCount: Int {
        keyStats.values.reduce(0, +)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题和统计
            HStack {
                Text("键盘热力图")
                    .font(.headline)
                Spacer()
                Text("总计 \(totalCount) 次按键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 键盘布局
            VStack(spacing: 4) {
                // 功能键行
                functionRow
                
                // 数字行
                numberRow
                
                // QWERTY 行
                qwertyRow
                
                // ASDF 行
                asdfRow
                
                // ZXCV 行
                zxcvRow
                
                // 空格行
                spaceRow
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            
            // 图例
            heatmapLegend
        }
    }
    
    // 间距常量
    private let keyGap: CGFloat = 2
    private let keyHeight: CGFloat = 40
    private let fnKeyHeight: CGFloat = 30  // 功能键高度 0.75U
    private let arrowKeyHeight: CGFloat = 19  // 方向键高度 约0.5U
    
    // MARK: - 功能键行 (esc + F1-F12，每个约1.0357U，高度0.75U)
    private var functionRow: some View {
        HStack(spacing: keyGap) {
            KeyCap(keyCode: 53, label: "esc", width: 41, height: fnKeyHeight, keyStats: keyStats, maxCount: maxCount)
            ForEach(KeyboardLayout.functionKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: fnKeyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - 数字行
    private var numberRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.numberRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - QWERTY 行
    private var qwertyRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.qwertyRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - ASDF 行
    private var asdfRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.asdfRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - ZXCV 行
    private var zxcvRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.zxcvRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - 空格行（含方向键）
    // 方向键紧挨着右 Option 键
    private var spaceRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.spaceRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, maxCount: maxCount)
            }
            // 方向键区域（紧挨着右 Option）
            arrowKeysView
        }
    }
    
    // MARK: - 方向键（半高布局）
    private var arrowKeysView: some View {
        VStack(spacing: keyGap) {
            // 上键居中
            HStack(spacing: keyGap) {
                Spacer().frame(width: 42) // 1U + gap 占位
                KeyCap(keyCode: 126, label: "↑", width: 40, height: arrowKeyHeight, keyStats: keyStats, maxCount: maxCount)
                Spacer().frame(width: 42)
            }
            // 左下右
            HStack(spacing: keyGap) {
                KeyCap(keyCode: 123, label: "←", width: 40, height: arrowKeyHeight, keyStats: keyStats, maxCount: maxCount)
                KeyCap(keyCode: 125, label: "↓", width: 40, height: arrowKeyHeight, keyStats: keyStats, maxCount: maxCount)
                KeyCap(keyCode: 124, label: "→", width: 40, height: arrowKeyHeight, keyStats: keyStats, maxCount: maxCount)
            }
        }
        .frame(height: keyHeight)
    }
    
    // MARK: - 热力图图例
    private var heatmapLegend: some View {
        HStack(spacing: 8) {
            Text("低")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // 渐变色条
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.blue.opacity(0.3),
                    Color.blue.opacity(0.5),
                    Color.orange.opacity(0.7),
                    Color.red.opacity(0.9)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text("高")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // 显示最高按键
            if let (topKeyCode, topCount) = keyStats.max(by: { $0.value < $1.value }) {
                HStack(spacing: 4) {
                    Text("最常用:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(KeyboardLayout.keyCodeToLabel(topKeyCode))
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("(\(topCount)次)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 单个按键（优化版本 - 移除动画和阴影以提升性能）
struct KeyCap: View {
    let keyCode: Int16
    let label: String
    let width: CGFloat
    var height: CGFloat = 36
    let keyStats: [Int16: Int]
    let maxCount: Int
    
    private var count: Int {
        keyStats[keyCode] ?? 0
    }
    
    private var intensity: Double {
        guard maxCount > 0 else { return 0 }
        return Double(count) / Double(maxCount)
    }
    
    private var backgroundColor: Color {
        if count == 0 {
            return Color(nsColor: .controlBackgroundColor)
        }
        
        // 根据强度计算颜色：从蓝色到橙色到红色
        if intensity < 0.3 {
            return Color.blue.opacity(0.1 + intensity * 0.5)
        } else if intensity < 0.6 {
            return Color.blue.opacity(0.3).blend(with: Color.orange.opacity(0.5), ratio: (intensity - 0.3) / 0.3)
        } else {
            return Color.orange.opacity(0.5).blend(with: Color.red.opacity(0.8), ratio: (intensity - 0.6) / 0.4)
        }
    }
    
    private var textColor: Color {
        if intensity > 0.5 {
            return .white
        }
        return .primary
    }
    
    var body: some View {
        Text(label)
            .font(.system(size: height > 20 ? (width > 50 ? 10 : 9) : 8, weight: .medium, design: .rounded))
            .foregroundStyle(textColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: height > 20 ? 5 : 3)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: height > 20 ? 5 : 3)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .help(count > 0 ? "\(label): \(count) 次" : label)
    }
}

// MARK: - 颜色混合扩展
extension Color {
    func blend(with other: Color, ratio: Double) -> Color {
        let ratio = max(0, min(1, ratio))
        
        // 简单的线性插值
        return Color(
            nsColor: NSColor(self).blended(withFraction: ratio, of: NSColor(other)) ?? NSColor(self)
        )
    }
}

// MARK: - 键盘布局数据
struct KeyboardLayout {
    struct KeyInfo: Identifiable {
        let id = UUID()
        let keyCode: Int16
        let label: String
        let width: CGFloat
        
        init(_ keyCode: Int16, _ label: String, width: CGFloat = 40) {
            self.keyCode = keyCode
            self.label = label
            self.width = width
        }
    }
    
    // 基准: 1U = 40px, 间距 2px
    // 总宽度: 14.5U = 580px + 13*2px间距 = 606px
    // 根据 KLE apple-wireless-keyboard.json 精确计算
    
    static let unit: CGFloat = 40  // 1U = 40px
    static let gap: CGFloat = 2    // 间距 2px
    
    // 功能键行: esc + F1-F12，每个 1.0357U (约41px)，高度 0.75U
    static let functionKeys: [KeyInfo] = [
        KeyInfo(122, "F1", width: 41), KeyInfo(120, "F2", width: 41),
        KeyInfo(99, "F3", width: 41), KeyInfo(118, "F4", width: 41),
        KeyInfo(96, "F5", width: 41), KeyInfo(97, "F6", width: 41),
        KeyInfo(98, "F7", width: 41), KeyInfo(100, "F8", width: 41),
        KeyInfo(101, "F9", width: 41), KeyInfo(109, "F10", width: 41),
        KeyInfo(103, "F11", width: 41), KeyInfo(111, "F12", width: 41)
    ]
    
    // 数字行: 13个1U + delete(1.5U) = 14.5U
    static let numberRowKeys: [KeyInfo] = [
        KeyInfo(50, "`"), KeyInfo(18, "1"), KeyInfo(19, "2"), KeyInfo(20, "3"),
        KeyInfo(21, "4"), KeyInfo(23, "5"), KeyInfo(22, "6"), KeyInfo(26, "7"),
        KeyInfo(28, "8"), KeyInfo(25, "9"), KeyInfo(29, "0"), KeyInfo(27, "-"),
        KeyInfo(24, "="), KeyInfo(51, "⌫", width: 60)  // 1.5U
    ]
    
    // Tab行: tab(1.5U) + 12个1U + \(1U) = 14.5U
    static let qwertyRowKeys: [KeyInfo] = [
        KeyInfo(48, "⇥", width: 60),  // 1.5U
        KeyInfo(12, "Q"), KeyInfo(13, "W"), KeyInfo(14, "E"), KeyInfo(15, "R"),
        KeyInfo(17, "T"), KeyInfo(16, "Y"), KeyInfo(32, "U"), KeyInfo(34, "I"),
        KeyInfo(31, "O"), KeyInfo(35, "P"), KeyInfo(33, "["), KeyInfo(30, "]"),
        KeyInfo(42, "\\")  // 1U
    ]
    
    // Caps行: caps(1.75U) + 11个1U + return(1.75U) = 14.5U
    static let asdfRowKeys: [KeyInfo] = [
        KeyInfo(57, "⇪", width: 70),  // 1.75U
        KeyInfo(0, "A"), KeyInfo(1, "S"), KeyInfo(2, "D"), KeyInfo(3, "F"),
        KeyInfo(5, "G"), KeyInfo(4, "H"), KeyInfo(38, "J"), KeyInfo(40, "K"),
        KeyInfo(37, "L"), KeyInfo(41, ";"), KeyInfo(39, "'"),
        KeyInfo(36, "⏎", width: 70)  // 1.75U
    ]
    
    // Shift行: shift(2.25U) + 10个1U + shift(2.25U) = 14.5U
    static let zxcvRowKeys: [KeyInfo] = [
        KeyInfo(56, "⇧", width: 90),  // 2.25U
        KeyInfo(6, "Z"), KeyInfo(7, "X"), KeyInfo(8, "C"), KeyInfo(9, "V"),
        KeyInfo(11, "B"), KeyInfo(45, "N"), KeyInfo(46, "M"),
        KeyInfo(43, ","), KeyInfo(47, "."), KeyInfo(44, "/"),
        KeyInfo(60, "⇧", width: 90)  // 2.25U
    ]
    
    // 空格行: fn(1U) + ctrl(1U) + opt(1U) + cmd(1.25U) + space(5U) + cmd(1.25U) + opt(1U) = 11.5U
    // 方向键从 x=11.5 开始，占 3U
    static let spaceRowKeys: [KeyInfo] = [
        KeyInfo(63, "fn"),              // 1U = 40
        KeyInfo(59, "⌃"),               // 1U = 40
        KeyInfo(58, "⌥"),               // 1U = 40
        KeyInfo(55, "⌘", width: 50),    // 1.25U = 50
        KeyInfo(49, "", width: 200),    // 5U = 200
        KeyInfo(54, "⌘", width: 50),    // 1.25U = 50
        KeyInfo(61, "⌥")                // 1U = 40
    ]
    // 空格行总宽: 40+40+40+50+200+50+40 = 460px + 6*2间距 = 472px
    // 方向键起始: 11.5U = 460px + 间距，占 3U = 120px + 间距
    
    // keyCode 转标签
    static func keyCodeToLabel(_ keyCode: Int16) -> String {
        // 先检查所有键盘布局
        let allKeys = functionKeys + numberRowKeys + qwertyRowKeys + asdfRowKeys + zxcvRowKeys + spaceRowKeys
        if let key = allKeys.first(where: { $0.keyCode == keyCode }), !key.label.isEmpty {
            return key.label
        }
        
        // 特殊键和修饰键
        switch keyCode {
        case 53: return "esc"
        case 36: return "⏎"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 117: return "⌦"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 54, 55: return "⌘"
        case 56, 60: return "⇧"
        case 57: return "⇪"
        case 58, 61: return "⌥"
        case 59: return "⌃"
        case 63: return "fn"
        default: return "[\(keyCode)]"
        }
    }
}

#Preview {
    KeyboardHeatmapView(keyStats: [
        0: 150,   // A
        1: 120,   // S
        2: 200,   // D
        3: 80,    // F
        49: 300,  // Space
        36: 100,  // Return
        51: 50,   // Delete
        12: 30,   // Q
        13: 180,  // W
        14: 220,  // E
        15: 90    // R
    ])
    .padding()
    .frame(width: 700)
}

