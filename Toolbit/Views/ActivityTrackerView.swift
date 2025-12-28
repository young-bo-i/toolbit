import SwiftUI

// MARK: - 活动追踪视图
struct ActivityTrackerView: View {
    // 使用 @ObservedObject 而不是 @StateObject，因为 monitor 是单例
    // 这样当 monitor 的 @Published 属性变化时，视图会自动刷新
    @ObservedObject private var monitor = ActivityMonitor.shared
    
    @State private var selectedTimeRange: TimeRange = .today
    @State private var keyStats: [Int16: Int] = [:]
    @State private var mouseStats: ActivityDataManager.MouseStats = .init()
    @State private var gestureStats: ActivityDataManager.GestureStats = .init()
    @State private var showClearConfirmation = false
    @State private var showClearDaysConfirmation = false
    @State private var clearDaysCount: Int = 7
    @State private var isLoading = false
    
    // 自定义时间范围
    @State private var customStartDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var customEndDate: Date = Date()
    @State private var showCustomDatePicker = false
    
    // 自动清理设置
    @AppStorage("AutoCleanupEnabled") private var autoCleanupEnabled = false
    @AppStorage("AutoCleanupDays") private var autoCleanupDays = 30
    
    enum TimeRange: String, CaseIterable {
        case today = "今日"
        case week = "本周"
        case month = "本月"
        case custom = "自定义"
    }
    
    // 合并实时数据和数据库数据
    private var combinedKeyStats: [Int16: Int] {
        if selectedTimeRange == .today {
            // 今日模式：使用实时数据
            return monitor.realtimeKeyStats
        }
        return keyStats
    }
    
    private var combinedMouseStats: (left: Int, right: Int, middle: Int, scroll: Int, other: Int) {
        if selectedTimeRange == .today {
            // 今日模式：使用实时数据
            return (
                monitor.realtimeLeftClickCount,
                monitor.realtimeRightClickCount,
                monitor.realtimeMiddleClickCount,
                monitor.realtimeScrollCount,
                monitor.realtimeOtherClickCount
            )
        }
        return (
            mouseStats.leftClickCount,
            mouseStats.rightClickCount,
            mouseStats.middleClickCount,
            mouseStats.scrollCount,
            mouseStats.otherClickCount
        )
    }
    
    private var combinedGestureScrollCount: Int {
        if selectedTimeRange == .today {
            // 今日模式：使用实时数据（双指滚动 = 滚轮事件）
            return monitor.realtimeGestureScrollCount + monitor.realtimeScrollCount
        }
        return gestureStats.scrollCount
    }
    
    // 转换时间范围类型
    private var timelineRangeType: TimelineRangeType {
        switch selectedTimeRange {
        case .today: return .today
        case .week: return .week
        case .month: return .month
        case .custom: return .custom
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 权限状态和控制
                permissionSection
                
                if monitor.hasPermission {
                    // 时间范围选择
                    timeRangePicker
                    
                    // 自定义时间范围选择器
                    if selectedTimeRange == .custom {
                        customDateRangePicker
                    }
                    
                    // 键盘热力图 + 时间轴热力图（横向，在键盘上方）
                    GroupBox {
                        VStack(spacing: 12) {
                            // 时间轴热力图（横向）
                            TimelineHeatmapView(
                                rangeType: timelineRangeType,
                                customStart: selectedTimeRange == .custom ? customStartDate : nil,
                                customEnd: selectedTimeRange == .custom ? customEndDate : nil
                            )
                            
                            // 键盘热力图
                            KeyboardHeatmapView(keyStats: combinedKeyStats)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // 鼠标和手势并排显示
                    HStack(alignment: .top, spacing: 16) {
                        // 鼠标热力图（使用合并后的数据）
                        GroupBox {
                            MouseHeatmapView(
                                leftClickCount: combinedMouseStats.left,
                                rightClickCount: combinedMouseStats.right,
                                middleClickCount: combinedMouseStats.middle,
                                scrollCount: combinedMouseStats.scroll,
                                otherClickCount: combinedMouseStats.other
                            )
                            .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 手势可视化（仅双指滚动）
                        GroupBox {
                            GestureVisualizationView(
                                scrollCount: combinedGestureScrollCount
                            )
                            .padding(.vertical, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // 数据管理
                    dataManagementSection
                }
            }
            .padding()
        }
        .navigationTitle(L10n.toolActivityTracker)
        .onAppear {
            loadStats()
            // 启动时检查是否需要自动清理
            if autoCleanupEnabled {
                performAutoCleanup()
            }
        }
        .onChange(of: selectedTimeRange) { _, _ in
            loadStats()
        }
        .alert("确认清除", isPresented: $showClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                ActivityDataManager.shared.clearAllData { [self] in
                    loadStats()
                    monitor.refreshTodayStats()
                }
            }
        } message: {
            Text("确定要清除所有活动数据吗？此操作不可撤销。")
        }
        .alert("确认清除", isPresented: $showClearDaysConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                let calendar = Calendar.current
                let cutoffDate = calendar.date(byAdding: .day, value: -clearDaysCount, to: Date())!
                ActivityDataManager.shared.clearDataBefore(date: cutoffDate) { [self] in
                    loadStats()
                    monitor.refreshTodayStats()
                }
            }
        } message: {
            Text("确定要清除 \(clearDaysCount) 天前的数据吗？此操作不可撤销。")
        }
    }
    
    // MARK: - 权限状态
    private var permissionSection: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: monitor.hasPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundStyle(monitor.hasPermission ? .green : .orange)
                        Text(monitor.hasPermission ? "已获得辅助功能权限" : "需要辅助功能权限")
                            .font(.headline)
                    }
                    
                    if !monitor.hasPermission {
                        Text("活动追踪需要辅助功能权限来监控键盘和鼠标事件。数据仅存储在本地，不会上传。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if monitor.hasPermission {
                    HStack(spacing: 12) {
                        // 监控状态指示
                        HStack(spacing: 6) {
                            Circle()
                                .fill(monitor.isMonitoring ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(monitor.isMonitoring ? "监控中" : "已暂停")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Toggle("", isOn: Binding(
                            get: { monitor.isMonitoring },
                            set: { enabled in
                                if enabled {
                                    monitor.startMonitoring()
                                } else {
                                    monitor.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                } else {
                    Button("授权") {
                        monitor.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - 时间范围选择
    private var timeRangePicker: some View {
        Picker("时间范围", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    // MARK: - 自定义日期范围选择器
    private var customDateRangePicker: some View {
        GroupBox {
            HStack(spacing: 20) {
                // 开始时间
                VStack(alignment: .leading, spacing: 4) {
                    Text("开始时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $customStartDate,
                        in: ...customEndDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                // 结束时间
                VStack(alignment: .leading, spacing: 4) {
                    Text("结束时间")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(
                        "",
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }
                
                Spacer()
                
                // 快捷选项
                Menu {
                    Button("过去1小时") {
                        customEndDate = Date()
                        customStartDate = Date().addingTimeInterval(-3600)
                        loadStats()
                    }
                    Button("过去6小时") {
                        customEndDate = Date()
                        customStartDate = Date().addingTimeInterval(-3600 * 6)
                        loadStats()
                    }
                    Button("过去12小时") {
                        customEndDate = Date()
                        customStartDate = Date().addingTimeInterval(-3600 * 12)
                        loadStats()
                    }
                    Divider()
                    Button("昨天") {
                        let calendar = Calendar.current
                        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
                        customStartDate = calendar.startOfDay(for: yesterday)
                        customEndDate = calendar.date(byAdding: .day, value: 1, to: customStartDate)!
                        loadStats()
                    }
                    Button("过去3天") {
                        customEndDate = Date()
                        customStartDate = Date().addingTimeInterval(-86400 * 3)
                        loadStats()
                    }
                    Button("过去7天") {
                        customEndDate = Date()
                        customStartDate = Date().addingTimeInterval(-86400 * 7)
                        loadStats()
                    }
                } label: {
                    Label("快捷选择", systemImage: "clock.arrow.circlepath")
                }
                
                // 应用按钮
                Button("查询") {
                    loadStats()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 4)
        }
        .onChange(of: customStartDate) { _, _ in
            // 确保开始时间不晚于结束时间
            if customStartDate > customEndDate {
                customEndDate = customStartDate
            }
        }
    }
    
    // MARK: - 数据管理
    private var dataManagementSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                // 标题行
                HStack {
                    Text("数据管理")
                        .font(.headline)
                    Spacer()
                }
                
                // 存储信息 + 操作按钮
                HStack(spacing: 24) {
                    // 存储空间
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "internaldrive")
                                .foregroundStyle(.blue)
                            Text("存储空间")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(ActivityDataManager.shared.getFormattedDatabaseSize())
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    
                    Divider()
                        .frame(height: 30)
                    
                    // 事件总数
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "number")
                                .foregroundStyle(.green)
                            Text("事件总数")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(ActivityDataManager.shared.getTotalEventCount())")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 12) {
                        Button {
                            loadStats()
                            monitor.refreshTodayStats()
                        } label: {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        
                        // 清理数据菜单
                        Menu {
                            Button("清除 3 天前的数据") {
                                clearDaysCount = 3
                                showClearDaysConfirmation = true
                            }
                            Button("清除 7 天前的数据") {
                                clearDaysCount = 7
                                showClearDaysConfirmation = true
                            }
                            Button("清除 14 天前的数据") {
                                clearDaysCount = 14
                                showClearDaysConfirmation = true
                            }
                            Button("清除 30 天前的数据") {
                                clearDaysCount = 30
                                showClearDaysConfirmation = true
                            }
                            Button("清除 90 天前的数据") {
                                clearDaysCount = 90
                                showClearDaysConfirmation = true
                            }
                            Divider()
                            Button("清除所有数据", role: .destructive) {
                                showClearConfirmation = true
                            }
                        } label: {
                            Label("清理数据", systemImage: "trash")
                        }
                    }
                }
                
                Divider()
                
                // 自动清理设置（默认保留30天）
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(autoCleanupEnabled ? .orange : .secondary)
                    
                    Text("自动清理：只保留最近")
                        .font(.subheadline)
                        .foregroundStyle(autoCleanupEnabled ? .primary : .secondary)
                    
                    Picker("", selection: $autoCleanupDays) {
                        Text("7 天").tag(7)
                        Text("14 天").tag(14)
                        Text("30 天").tag(30)
                        Text("60 天").tag(60)
                        Text("90 天").tag(90)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                    .disabled(!autoCleanupEnabled)
                    
                    Text("的数据")
                        .font(.subheadline)
                        .foregroundStyle(autoCleanupEnabled ? .primary : .secondary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoCleanupEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 执行自动清理
    private func performAutoCleanup() {
        guard autoCleanupEnabled else { return }
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -autoCleanupDays, to: Date())!
        ActivityDataManager.shared.clearDataBefore(date: cutoffDate) { [self] in
            loadStats()
        }
    }
    
    // MARK: - 加载数据
    private func loadStats() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newKeyStats: [Int16: Int]
            let newMouseStats: ActivityDataManager.MouseStats
            let newGestureStats: ActivityDataManager.GestureStats
            
            switch selectedTimeRange {
            case .today:
                // 今日数据：从数据库加载到实时统计
                newKeyStats = ActivityDataManager.shared.getTodayKeyStats()
                newMouseStats = ActivityDataManager.shared.getTodayMouseStats()
                newGestureStats = ActivityDataManager.shared.getTodayGestureStats()
                
                // 更新 monitor 的实时统计
                DispatchQueue.main.async {
                    self.monitor.realtimeKeyStats = newKeyStats
                    self.monitor.realtimeLeftClickCount = newMouseStats.leftClickCount
                    self.monitor.realtimeRightClickCount = newMouseStats.rightClickCount
                    self.monitor.realtimeMiddleClickCount = newMouseStats.middleClickCount
                    self.monitor.realtimeScrollCount = newMouseStats.scrollCount
                    self.monitor.realtimeOtherClickCount = newMouseStats.otherClickCount
                }
                
            case .week:
                newKeyStats = ActivityDataManager.shared.getWeekKeyStats()
                newMouseStats = ActivityDataManager.shared.getWeekMouseStats()
                newGestureStats = ActivityDataManager.shared.getWeekGestureStats()
                
            case .month:
                newKeyStats = ActivityDataManager.shared.getMonthKeyStats()
                newMouseStats = ActivityDataManager.shared.getMonthMouseStats()
                newGestureStats = ActivityDataManager.shared.getMonthGestureStats()
                
            case .custom:
                newKeyStats = ActivityDataManager.shared.getKeyStats(from: customStartDate, to: customEndDate)
                newMouseStats = ActivityDataManager.shared.getMouseStats(from: customStartDate, to: customEndDate)
                newGestureStats = ActivityDataManager.shared.getGestureStats(from: customStartDate, to: customEndDate)
            }
            
            DispatchQueue.main.async {
                self.keyStats = newKeyStats
                self.mouseStats = newMouseStats
                self.gestureStats = newGestureStats
                self.isLoading = false
            }
        }
    }
    
    // 注意：不再需要定时器！
    // SwiftUI 会自动响应 ActivityMonitor 的 @Published 属性变化
    // 当 realtimeKeyStats 等属性更新时，combinedKeyStats 等 computed property 会重新计算
    // 视图会自动刷新显示最新数据
}

#Preview {
    ActivityTrackerView()
}
