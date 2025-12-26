import SwiftUI

// MARK: - 时间范围类型（用于时间轴显示）
enum TimelineRangeType {
    case today
    case week
    case month
    case custom
}

// MARK: - 横向时间轴热力图视图
struct TimelineHeatmapView: View {
    let rangeType: TimelineRangeType
    let customStart: Date?
    let customEnd: Date?
    
    private let minSlotWidth: CGFloat = 8  // 最小格子宽度
    
    // 获取完整的时间范围
    private var fullRange: (start: Date, end: Date) {
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
            let data = ActivityDataManager.shared.getTimelineHeatmapData(
                from: fullRange.start,
                to: fullRange.end,
                slotCount: slotCount,
                currentTime: currentTime
            )
            let maxCount = data.map(\.count).max() ?? 1
            
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
                        ForEach(data) { slot in
                            TimeSlotCell(slot: slot, maxCount: maxCount)
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

// MARK: - 时间段单元格
struct TimeSlotCell: View {
    let slot: ActivityDataManager.TimeSlotStats
    let maxCount: Int
    
    @State private var isHovered = false
    
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
            .overlay(
                // 悬浮提示
                Group {
                    if isHovered {
                        VStack(spacing: 2) {
                            Text(slot.label)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                            if slot.isFuture {
                                Text("未来")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(slot.count) 次")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                        .offset(y: -30)
                    }
                }
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
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
