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
    
    // MARK: - 功能键行
    private var functionRow: some View {
        HStack(spacing: 4) {
            KeyCap(keyCode: 53, label: "esc", width: 40, keyStats: keyStats, maxCount: maxCount)
            Spacer().frame(width: 8)
            ForEach(KeyboardLayout.functionKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: 36, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - 数字行
    private var numberRow: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardLayout.numberRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - QWERTY 行
    private var qwertyRow: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardLayout.qwertyRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - ASDF 行
    private var asdfRow: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardLayout.asdfRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - ZXCV 行
    private var zxcvRow: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardLayout.zxcvRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, keyStats: keyStats, maxCount: maxCount)
            }
        }
    }
    
    // MARK: - 空格行
    private var spaceRow: some View {
        HStack(spacing: 4) {
            ForEach(KeyboardLayout.spaceRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, keyStats: keyStats, maxCount: maxCount)
            }
        }
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

// MARK: - 单个按键
struct KeyCap: View {
    let keyCode: Int16
    let label: String
    let width: CGFloat
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
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: width > 50 ? 10 : 9, weight: .medium, design: .rounded))
                .foregroundStyle(textColor)
            
            if count > 0 && isHovered {
                Text("\(count)")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.8))
            }
        }
        .frame(width: width, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.primary.opacity(isHovered ? 0.3 : 0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: isHovered ? 2 : 1, x: 0, y: 1)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
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
        
        init(_ keyCode: Int16, _ label: String, width: CGFloat = 36) {
            self.keyCode = keyCode
            self.label = label
            self.width = width
        }
    }
    
    // macOS keyCode 映射
    // 参考: https://eastmanreference.com/complete-list-of-applescript-key-codes
    
    static let functionKeys: [KeyInfo] = [
        KeyInfo(122, "F1"), KeyInfo(120, "F2"), KeyInfo(99, "F3"), KeyInfo(118, "F4"),
        KeyInfo(96, "F5"), KeyInfo(97, "F6"), KeyInfo(98, "F7"), KeyInfo(100, "F8"),
        KeyInfo(101, "F9"), KeyInfo(109, "F10"), KeyInfo(103, "F11"), KeyInfo(111, "F12")
    ]
    
    static let numberRowKeys: [KeyInfo] = [
        KeyInfo(50, "`"), KeyInfo(18, "1"), KeyInfo(19, "2"), KeyInfo(20, "3"),
        KeyInfo(21, "4"), KeyInfo(23, "5"), KeyInfo(22, "6"), KeyInfo(26, "7"),
        KeyInfo(28, "8"), KeyInfo(25, "9"), KeyInfo(29, "0"), KeyInfo(27, "-"),
        KeyInfo(24, "="), KeyInfo(51, "⌫", width: 56)
    ]
    
    static let qwertyRowKeys: [KeyInfo] = [
        KeyInfo(48, "⇥", width: 50),
        KeyInfo(12, "Q"), KeyInfo(13, "W"), KeyInfo(14, "E"), KeyInfo(15, "R"),
        KeyInfo(17, "T"), KeyInfo(16, "Y"), KeyInfo(32, "U"), KeyInfo(34, "I"),
        KeyInfo(31, "O"), KeyInfo(35, "P"), KeyInfo(33, "["), KeyInfo(30, "]"),
        KeyInfo(42, "\\", width: 50)
    ]
    
    static let asdfRowKeys: [KeyInfo] = [
        KeyInfo(57, "⇪", width: 58),
        KeyInfo(0, "A"), KeyInfo(1, "S"), KeyInfo(2, "D"), KeyInfo(3, "F"),
        KeyInfo(5, "G"), KeyInfo(4, "H"), KeyInfo(38, "J"), KeyInfo(40, "K"),
        KeyInfo(37, "L"), KeyInfo(41, ";"), KeyInfo(39, "'"),
        KeyInfo(36, "⏎", width: 62)
    ]
    
    static let zxcvRowKeys: [KeyInfo] = [
        KeyInfo(56, "⇧", width: 76),
        KeyInfo(6, "Z"), KeyInfo(7, "X"), KeyInfo(8, "C"), KeyInfo(9, "V"),
        KeyInfo(11, "B"), KeyInfo(45, "N"), KeyInfo(46, "M"),
        KeyInfo(43, ","), KeyInfo(47, "."), KeyInfo(44, "/"),
        KeyInfo(60, "⇧", width: 76)
    ]
    
    static let spaceRowKeys: [KeyInfo] = [
        KeyInfo(59, "⌃", width: 44),
        KeyInfo(58, "⌥", width: 44),
        KeyInfo(55, "⌘", width: 52),
        KeyInfo(49, "Space", width: 200),
        KeyInfo(54, "⌘", width: 52),
        KeyInfo(61, "⌥", width: 44),
        KeyInfo(62, "⌃", width: 44)
    ]
    
    // keyCode 转标签
    static func keyCodeToLabel(_ keyCode: Int16) -> String {
        let allKeys = functionKeys + numberRowKeys + qwertyRowKeys + asdfRowKeys + zxcvRowKeys + spaceRowKeys
        if let key = allKeys.first(where: { $0.keyCode == keyCode }) {
            return key.label
        }
        
        // 特殊键
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

