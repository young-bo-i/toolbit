import SwiftUI

// MARK: - 热力图颜色计算器
struct HeatmapColorCalculator {
    let keyStats: [Int16: Int]
    
    // 使用对数缩放 + 百分位数归一化来处理极端值
    private var sortedCounts: [Int] {
        keyStats.values.filter { $0 > 0 }.sorted()
    }
    
    /// 计算对数缩放后的强度值 (0-1)
    /// 使用 log1p 避免 log(0) 问题，并用百分位数归一化
    func intensity(for count: Int) -> Double {
        guard count > 0 else { return 0 }
        
        let counts = sortedCounts
        guard !counts.isEmpty else { return 0 }
        
        // 方案：对数缩放 + 分位数映射
        // 1. 对数缩放压缩极端值
        let logCount = log(Double(count) + 1)
        let logMax = log(Double(counts.last ?? 1) + 1)
        let logMin = log(Double(counts.first ?? 1) + 1)
        
        // 2. 归一化到 0-1
        guard logMax > logMin else { return 0.5 }
        let normalized = (logCount - logMin) / (logMax - logMin)
        
        // 3. 应用 gamma 校正，让中间值更明显
        // gamma < 1 会让低值更亮，gamma > 1 会让高值更亮
        let gamma = 0.6  // 让低频按键更容易看到
        return pow(normalized, gamma)
    }
    
    /// 根据强度获取颜色 - 冷暖色阶（蓝→红）
    func color(for count: Int) -> Color {
        guard count > 0 else {
            return Color(nsColor: .controlBackgroundColor)
        }
        
        let t = intensity(for: count)
        return interpolateColor(t: t)
    }
    
    /// 插值计算颜色 - 冷到暖色阶
    /// 低频：冷色（深蓝） → 高频：暖色（红色）
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
    
    /// 文字颜色 - 根据背景亮度自动选择
    func textColor(for count: Int) -> Color {
        guard count > 0 else { return .primary }
        
        let t = intensity(for: count)
        // 中间浅色区域用深色文字，两端深色区域用白色文字
        if t > 0.25 && t < 0.7 {
            return Color(white: 0.15)
        }
        return .white
    }
}

// MARK: - 键盘热力图视图
struct KeyboardHeatmapView<TimelineContent: View, RightContent: View>: View {
    let keyStats: [Int16: Int]
    let timelineContent: TimelineContent
    let rightContent: RightContent
    
    // 初始化器：带时间轴和右侧内容
    init(keyStats: [Int16: Int], 
         @ViewBuilder timelineContent: () -> TimelineContent,
         @ViewBuilder rightContent: () -> RightContent) {
        self.keyStats = keyStats
        self.timelineContent = timelineContent()
        self.rightContent = rightContent()
    }
    
    // 颜色计算器
    private var colorCalculator: HeatmapColorCalculator {
        HeatmapColorCalculator(keyStats: keyStats)
    }
    
    // 计算最大按键次数（用于显示）
    private var maxCount: Int {
        keyStats.values.max() ?? 1
    }
    
    // 总按键次数
    private var totalCount: Int {
        keyStats.values.reduce(0, +)
    }
    
    // Top 5 按键
    private var top5Keys: [(keyCode: Int16, count: Int)] {
        keyStats.sorted { $0.value > $1.value }
            .prefix(5)
            .map { (keyCode: $0.key, count: $0.value) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部：时间轴
            timelineContent
            
            // 主体区域：左侧图例 + 键盘 + 右侧内容（鼠标）
            HStack(alignment: .center, spacing: 16) {
                // 左侧：竖向热力图图例
                verticalLegend
                
                // 中间：键盘布局
                VStack(spacing: 4) {
                    functionRow
                    numberRow
                    qwertyRow
                    asdfRow
                    zxcvRow
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
                
                // 右侧：外部传入的内容（鼠标）
                rightContent
            }
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
            KeyCap(keyCode: 53, label: "esc", width: 41, height: fnKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            ForEach(KeyboardLayout.functionKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: fnKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
    }
    
    // MARK: - 数字行
    private var numberRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.numberRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
    }
    
    // MARK: - QWERTY 行
    private var qwertyRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.qwertyRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
    }
    
    // MARK: - ASDF 行
    private var asdfRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.asdfRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
    }
    
    // MARK: - ZXCV 行
    private var zxcvRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.zxcvRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
    }
    
    // MARK: - 空格行（含方向键）
    private var spaceRow: some View {
        HStack(spacing: keyGap) {
            ForEach(KeyboardLayout.spaceRowKeys, id: \.keyCode) { key in
                KeyCap(keyCode: key.keyCode, label: key.label, width: key.width, height: keyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
            arrowKeysView
        }
    }
    
    // MARK: - 方向键（半高布局）
    private var arrowKeysView: some View {
        VStack(spacing: keyGap) {
            HStack(spacing: keyGap) {
                Spacer().frame(width: 42)
                KeyCap(keyCode: 126, label: "↑", width: 40, height: arrowKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
                Spacer().frame(width: 42)
            }
            HStack(spacing: keyGap) {
                KeyCap(keyCode: 123, label: "←", width: 40, height: arrowKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
                KeyCap(keyCode: 125, label: "↓", width: 40, height: arrowKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
                KeyCap(keyCode: 124, label: "→", width: 40, height: arrowKeyHeight, keyStats: keyStats, colorCalculator: colorCalculator)
            }
        }
        .frame(height: keyHeight)
    }
    
    // MARK: - 竖向热力图图例
    private var verticalLegend: some View {
        VStack(spacing: 4) {
            Text("高")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // 竖向渐变色条 - 冷暖色阶（红→蓝）
            LinearGradient(
                colors: [
                    Color(red: 0.843, green: 0.188, blue: 0.153),  // 红色
                    Color(red: 0.957, green: 0.427, blue: 0.263),  // 橙红色
                    Color(red: 0.992, green: 0.682, blue: 0.380),  // 橙黄色
                    Color(red: 0.996, green: 0.878, blue: 0.565),  // 淡黄色
                    Color(red: 0.878, green: 0.953, blue: 0.973),  // 极淡青
                    Color(red: 0.671, green: 0.851, blue: 0.914),  // 淡青色
                    Color(red: 0.455, green: 0.678, blue: 0.820),  // 浅蓝色
                    Color(red: 0.270, green: 0.459, blue: 0.706),  // 蓝色
                    Color(red: 0.192, green: 0.212, blue: 0.584),  // 深蓝色
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 12, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            
            Text("低")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Top 5 按键视图（紧凑横向布局）
    private var top5View: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOP 5")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
            
            // 横向排列的 Top 5 按键
            HStack(spacing: 4) {
                ForEach(Array(top5Keys.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 2) {
                        // 按键（模拟键帽样式）
                        Text(KeyboardLayout.keyCodeToLabel(item.keyCode))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(colorCalculator.textColor(for: item.count))
                            .frame(width: 32, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(colorCalculator.color(for: item.count))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        
                        // 次数
                        Text("\(item.count)")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// 便捷初始化器
extension KeyboardHeatmapView where TimelineContent == EmptyView, RightContent == EmptyView {
    init(keyStats: [Int16: Int]) {
        self.keyStats = keyStats
        self.timelineContent = EmptyView()
        self.rightContent = EmptyView()
    }
}

extension KeyboardHeatmapView where RightContent == EmptyView {
    init(keyStats: [Int16: Int], @ViewBuilder timelineContent: () -> TimelineContent) {
        self.keyStats = keyStats
        self.timelineContent = timelineContent()
        self.rightContent = EmptyView()
    }
}

// MARK: - 数字格式化（带单位）
struct CountFormatter {
    /// 格式化数字，超过一定值显示单位
    /// 201 -> "201", 1100 -> "1.1K", 24000 -> "2.4W"
    static func format(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 10000 {
            // 1000-9999 显示 K
            let k = Double(count) / 1000.0
            if k == Double(Int(k)) {
                return "\(Int(k))K"
            }
            return String(format: "%.1fK", k)
        } else {
            // 10000+ 显示 W（万）
            let w = Double(count) / 10000.0
            if w == Double(Int(w)) {
                return "\(Int(w))W"
            }
            return String(format: "%.1fW", w)
        }
    }
}

// MARK: - 单个按键（使用对数缩放的颜色计算）
struct KeyCap: View {
    let keyCode: Int16
    let label: String
    let width: CGFloat
    var height: CGFloat = 36
    let keyStats: [Int16: Int]
    let colorCalculator: HeatmapColorCalculator
    
    private var count: Int {
        keyStats[keyCode] ?? 0
    }
    
    private var backgroundColor: Color {
        colorCalculator.color(for: count)
    }
    
    private var textColor: Color {
        colorCalculator.textColor(for: count)
    }
    
    private var formattedCount: String {
        CountFormatter.format(count)
    }
    
    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: height > 20 ? (width > 50 ? 9 : 8) : 7, weight: .medium, design: .rounded))
            
            if count > 0 {
                Text(formattedCount)
                    .font(.system(size: height > 20 ? 7 : 6, weight: .regular, design: .monospaced))
                    .opacity(0.8)
            }
        }
        .foregroundStyle(textColor)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: height > 20 ? 5 : 3)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: height > 20 ? 5 : 3)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .help(count > 0 ? "\(label): \(count) 次" : label)
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

// 测试数据：模拟断崖式领先的情况
#Preview("正常分布") {
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

#Preview("断崖式领先") {
    // 空格键 5000 次，其他键 10-100 次
    KeyboardHeatmapView(keyStats: [
        0: 80,    // A
        1: 60,    // S
        2: 100,   // D
        3: 40,    // F
        49: 5000, // Space - 断崖式领先
        36: 50,   // Return
        51: 30,   // Delete
        12: 15,   // Q
        13: 90,   // W
        14: 110,  // E
        15: 45,   // R
        55: 2000, // Command - 第二高
    ])
    .padding()
    .frame(width: 700)
}

