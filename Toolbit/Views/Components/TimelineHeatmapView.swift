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
                    
                    // 当前时间标签（根据位置偏移）
                    if showCurrentTimeIndicator && currentTimeRatio > 0.1 && currentTimeRatio < 0.9 {
                        Text(currentTimeLabel)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange)
                            .position(x: width * currentTimeRatio, y: 6)
                    }
                }
                .frame(height: 14)
                
                // 热力条 + 当前时间指示线
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
                }
                .frame(height: 16)
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
        guard maxCount > 0 else { return 0 }
        return Double(slot.count) / Double(maxCount)
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
        
        // 有数据：根据强度计算颜色
        if intensity < 0.3 {
            return Color.blue.opacity(0.3 + intensity * 0.4)
        } else if intensity < 0.6 {
            return Color.blue.opacity(0.5).blend(with: Color.orange.opacity(0.7), ratio: (intensity - 0.3) / 0.3)
        } else {
            return Color.orange.opacity(0.7).blend(with: Color.red.opacity(0.9), ratio: (intensity - 0.6) / 0.4)
        }
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
