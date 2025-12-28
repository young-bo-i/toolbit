import SwiftUI

// MARK: - 时间范围类型（用于时间轴显示）
enum TimelineRangeType: Equatable {
    case today
    case week
    case month
    case custom
}

// MARK: - 时间轴数据缓存
private class TimelineDataCache: ObservableObject {
    @Published var data: [ActivityDataManager.TimeSlotStats] = []
    @Published var maxCount: Int = 1
    
    private var lastRangeType: TimelineRangeType?
    private var lastCustomStart: Date?
    private var lastCustomEnd: Date?
    private var lastSlotCount: Int = 0
    private var lastLoadTime: Date = .distantPast
    
    func loadDataIfNeeded(
        rangeType: TimelineRangeType,
        customStart: Date?,
        customEnd: Date?,
        slotCount: Int,
        forceReload: Bool = false
    ) {
        // 检查是否需要重新加载（参数变化或超过5秒）
        let needsReload = forceReload ||
            rangeType != lastRangeType ||
            customStart != lastCustomStart ||
            customEnd != lastCustomEnd ||
            abs(slotCount - lastSlotCount) > 5 ||
            Date().timeIntervalSince(lastLoadTime) > 5.0
        
        guard needsReload else { return }
        
        lastRangeType = rangeType
        lastCustomStart = customStart
        lastCustomEnd = customEnd
        lastSlotCount = slotCount
        lastLoadTime = Date()
        
        // 在后台线程加载数据
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fullRange = Self.getFullRange(rangeType: rangeType, customStart: customStart, customEnd: customEnd)
            let currentTime = Date()
            let newData = ActivityDataManager.shared.getTimelineHeatmapData(
                from: fullRange.start,
                to: fullRange.end,
                slotCount: slotCount,
                currentTime: currentTime
            )
            let newMaxCount = newData.map(\.count).max() ?? 1
            
            DispatchQueue.main.async {
                self?.data = newData
                self?.maxCount = newMaxCount
            }
        }
    }
    
    static func getFullRange(rangeType: TimelineRangeType, customStart: Date?, customEnd: Date?) -> (start: Date, end: Date) {
        switch rangeType {
        case .today:
            return ActivityDataManager.shared.getTodayFullRange()
        case .week:
            return ActivityDataManager.shared.getWeekFullRange()
        case .month:
            return ActivityDataManager.shared.getMonthFullRange()
        case .custom:
            return (customStart ?? Date(), customEnd ?? Date())
        }
    }
}

// MARK: - 横向时间轴热力图视图
struct TimelineHeatmapView: View {
    let rangeType: TimelineRangeType
    let customStart: Date?
    let customEnd: Date?
    
    @StateObject private var cache = TimelineDataCache()
    @State private var viewWidth: CGFloat = 300
    @State private var hoverLocation: CGFloat? = nil  // 鼠标 hover 位置
    @State private var isHovering: Bool = false
    
    private let minSlotWidth: CGFloat = 8  // 最小格子宽度
    
    // 获取完整的时间范围
    private var fullRange: (start: Date, end: Date) {
        TimelineDataCache.getFullRange(rangeType: rangeType, customStart: customStart, customEnd: customEnd)
    }
    
    // 当前时间
    private var currentTime: Date { Date() }
    
    // 是否显示当前时间指示器（自定义模式不显示）
    private var showCurrentTimeIndicator: Bool {
        rangeType != .custom
    }
    
    // 时间标签格式
    private var startTimeLabel: String {
        formatTime(fullRange.start, for: rangeType, isStart: true)
    }
    
    private var endTimeLabel: String {
        formatTime(fullRange.end, for: rangeType, isStart: false)
    }
    
    private var currentTimeLabel: String {
        formatTime(currentTime, for: rangeType, isCurrent: true)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let slotCount = max(Int(width / minSlotWidth), 10)
            
            // 计算当前时间在时间轴上的位置比例
            let currentTimeRatio: CGFloat = {
                let totalDuration = fullRange.end.timeIntervalSince(fullRange.start)
                let currentDuration = currentTime.timeIntervalSince(fullRange.start)
                guard totalDuration > 0 else { return 0 }
                return CGFloat(min(max(currentDuration / totalDuration, 0), 1))
            }()
            
            VStack(spacing: 4) {
                // 时间标签行
                ZStack {
                    HStack {
                        Text(startTimeLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(endTimeLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Hover 时间标签（优先显示）
                    if isHovering, let hoverX = hoverLocation {
                        let hoverRatio = min(max(hoverX / width, 0), 1)
                        let hoverTime = getTimeForRatio(hoverRatio)
                        Text(formatHoverTime(hoverTime))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: .black.opacity(0.1), radius: 2)
                            )
                            .position(x: clampLabelPosition(hoverX, width: width), y: 6)
                    }
                    // 当前时间标签（hover 时隐藏）
                    else if showCurrentTimeIndicator && currentTimeRatio > 0.1 && currentTimeRatio < 0.9 {
                        Text(currentTimeLabel)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange)
                            .position(x: width * currentTimeRatio, y: 6)
                    }
                }
                .frame(height: 14)
                
                // 热力条 + 当前时间指示线 + Hover 指示线
                ZStack(alignment: .leading) {
                    // 热力条
                    HStack(spacing: 1) {
                        ForEach(cache.data) { slot in
                            TimeSlotCell(slot: slot, maxCount: cache.maxCount)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 当前时间指示线
                    if showCurrentTimeIndicator {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 2)
                            .offset(x: width * currentTimeRatio - 1)
                    }
                    
                    // Hover 指示线
                    if isHovering, let hoverX = hoverLocation {
                        Rectangle()
                            .fill(Color.primary.opacity(0.6))
                            .frame(width: 1)
                            .offset(x: hoverX)
                    }
                }
                .frame(height: 16)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        isHovering = true
                        hoverLocation = location.x
                    case .ended:
                        isHovering = false
                        hoverLocation = nil
                    }
                }
            }
            .onAppear {
                cache.loadDataIfNeeded(
                    rangeType: rangeType,
                    customStart: customStart,
                    customEnd: customEnd,
                    slotCount: slotCount
                )
            }
            .onChange(of: rangeType) { _, _ in
                cache.loadDataIfNeeded(
                    rangeType: rangeType,
                    customStart: customStart,
                    customEnd: customEnd,
                    slotCount: slotCount,
                    forceReload: true
                )
            }
        }
        .frame(height: 36)
    }
    
    // MARK: - Hover 相关函数
    
    /// 根据位置比例获取对应的时间
    private func getTimeForRatio(_ ratio: CGFloat) -> Date {
        let totalDuration = fullRange.end.timeIntervalSince(fullRange.start)
        let offset = totalDuration * Double(ratio)
        return fullRange.start.addingTimeInterval(offset)
    }
    
    /// 格式化 hover 时显示的时间
    private func formatHoverTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        switch rangeType {
        case .today:
            formatter.dateFormat = "HH:mm"
        case .week:
            formatter.dateFormat = "E HH:mm"
        case .month:
            formatter.dateFormat = "M/d HH:mm"
        case .custom:
            formatter.dateFormat = "M/d HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// 限制标签位置，防止超出边界
    private func clampLabelPosition(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 50  // 估计标签宽度
        let minX = labelWidth / 2
        let maxX = width - labelWidth / 2
        return min(max(x, minX), maxX)
    }
    
    // MARK: - 时间格式化
    private func formatTime(_ date: Date, for type: TimelineRangeType, isStart: Bool = false, isCurrent: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        switch type {
        case .today:
            formatter.dateFormat = "HH:mm"
            if !isStart && !isCurrent {
                return "24:00"  // 结束时间显示为24:00
            }
        case .week:
            if isCurrent {
                formatter.dateFormat = "E HH:mm"
            } else {
                formatter.dateFormat = "E"
            }
        case .month:
            if isCurrent {
                formatter.dateFormat = "d日 HH:mm"
            } else {
                formatter.dateFormat = "d日"
            }
        case .custom:
            formatter.dateFormat = "MM/dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - 时间段单元格（优化版本 - 移除 hover 动画）
struct TimeSlotCell: View {
    let slot: ActivityDataManager.TimeSlotStats
    let maxCount: Int
    
    private var intensity: Double {
        guard maxCount > 0, slot.count > 0 else { return 0 }
        // 使用对数缩放
        let logCount = log(Double(slot.count) + 1)
        let logMax = log(Double(maxCount) + 1)
        guard logMax > 0 else { return 0 }
        let normalized = logCount / logMax
        // gamma 校正
        return pow(normalized, 0.6)
    }
    
    private var backgroundColor: Color {
        // 未来时间
        if slot.isFuture {
            return Color.gray.opacity(0.1)
        }
        
        // 无数据
        if slot.count == 0 {
            return Color.gray.opacity(0.25)
        }
        
        // 有数据：使用与键盘相同的冷暖色阶
        return interpolateColor(t: intensity)
    }
    
    /// 插值计算颜色 - 冷到暖色阶（与键盘热力图一致）
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
    
    private var tooltipText: String {
        if slot.isFuture {
            return "\(slot.label) (未来)"
        }
        return "\(slot.label): \(slot.count) 次"
    }
    
    var body: some View {
        Rectangle()
            .fill(backgroundColor)
            .overlay(
                // 未来时间显示斜线纹理
                Group {
                    if slot.isFuture {
                        DiagonalLines()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    }
                }
            )
            .help(tooltipText)
    }
}

// MARK: - 斜线纹理（用于未来时间）
struct DiagonalLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 4
        
        var x: CGFloat = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        GroupBox("今日") {
            TimelineHeatmapView(
                rangeType: .today,
                customStart: nil,
                customEnd: nil
            )
        }
        
        GroupBox("本周") {
            TimelineHeatmapView(
                rangeType: .week,
                customStart: nil,
                customEnd: nil
            )
        }
        
        GroupBox("本月") {
            TimelineHeatmapView(
                rangeType: .month,
                customStart: nil,
                customEnd: nil
            )
        }
    }
    .padding()
    .frame(width: 600)
}
