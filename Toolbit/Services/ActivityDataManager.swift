import Foundation
import CoreData
import SQLite3

// MARK: - 活动数据管理器
class ActivityDataManager {
    static let shared = ActivityDataManager()
    
    // 压缩数据缓存（避免频繁读取数据库）
    private var compactDataCache: [Int32: Data] = [:]
    private let cacheLock = NSLock()
    
    // MARK: - Core Data 栈
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ActivityTracker")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {}
    
    // MARK: - 保存
    func save() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 批量插入（压缩存储）
    func batchInsert(_ events: [RawEventData]) {
        guard !events.isEmpty else { return }
        
        let context = persistentContainer.newBackgroundContext()
        context.perform { [weak self] in
            guard let self = self else { return }
            
            // 按天分组事件
            var eventsByDay: [Int32: [RawEventData]] = [:]
            for event in events {
                let dayTs = CompactEventCodec.dayTimestamp(for: event.timestamp)
                eventsByDay[dayTs, default: []].append(event)
            }
            
            // 为每天追加数据
            for (dayTs, dayEvents) in eventsByDay {
                let dayStart = CompactEventCodec.dayStart(from: dayTs)
                let newData = CompactEventCodec.encodeEvents(dayEvents, dayStart: dayStart)
                
                // 查找或创建当天的记录
                let request = NSFetchRequest<NSManagedObject>(entityName: "CompactEvent")
                request.predicate = NSPredicate(format: "dayTimestamp == %d", dayTs)
                request.fetchLimit = 1
                
                do {
                    let results = try context.fetch(request)
                    
                    if let existing = results.first, var existingData = existing.value(forKey: "data") as? Data {
                        // 追加到现有数据
                        existingData.append(newData)
                        existing.setValue(existingData, forKey: "data")
                    } else {
                        // 创建新记录
                        let entity = NSEntityDescription.insertNewObject(forEntityName: "CompactEvent", into: context)
                        entity.setValue(dayTs, forKey: "dayTimestamp")
                        entity.setValue(newData, forKey: "data")
                    }
                    
                    try context.save()
                    
                    // 更新缓存
                    self.cacheLock.lock()
                    if var cachedData = self.compactDataCache[dayTs] {
                        cachedData.append(newData)
                        self.compactDataCache[dayTs] = cachedData
                    }
                    self.cacheLock.unlock()
                    
                    print("Compact inserted \(dayEvents.count) events for day \(dayTs)")
                } catch {
                    print("Failed to insert compact events: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 获取压缩数据
    
    /// 获取指定日期范围的压缩数据
    private func getCompactData(from startDate: Date, to endDate: Date) -> [(dayTimestamp: Int32, data: Data)] {
        let startDayTs = CompactEventCodec.dayTimestamp(for: startDate)
        let endDayTs = CompactEventCodec.dayTimestamp(for: endDate)
        
        let request = NSFetchRequest<NSManagedObject>(entityName: "CompactEvent")
        request.predicate = NSPredicate(format: "dayTimestamp >= %d AND dayTimestamp <= %d", startDayTs, endDayTs)
        request.sortDescriptors = [NSSortDescriptor(key: "dayTimestamp", ascending: true)]
        
        do {
            let results = try viewContext.fetch(request)
            return results.compactMap { obj -> (Int32, Data)? in
                guard let dayTs = obj.value(forKey: "dayTimestamp") as? Int32,
                      let data = obj.value(forKey: "data") as? Data else {
                    return nil
                }
                return (dayTs, data)
            }
        } catch {
            print("Failed to fetch compact data: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 查询
    
    /// 获取今日统计
    func getTodayStats() -> ActivityStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return getStatistics(from: startOfDay, to: endOfDay)
    }
    
    /// 获取本周统计
    func getWeekStats() -> ActivityStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        
        return getStatistics(from: startOfWeek, to: endOfWeek)
    }
    
    /// 获取本月统计
    func getMonthStats() -> ActivityStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return getStatistics(from: startOfMonth, to: endOfMonth)
    }
    
    /// 获取指定时间范围的统计
    func getStatistics(from startDate: Date, to endDate: Date) -> ActivityStats {
        var stats = ActivityStats(startDate: startDate, endDate: endDate)
        
        // 从压缩存储获取统计
        let compactData = getCompactData(from: startDate, to: endDate)
        for (_, data) in compactData {
            let keyStats = CompactEventCodec.countKeyStats(from: data)
            stats.keyboardCount += keyStats.values.reduce(0, +)
            
            let mouseStats = CompactEventCodec.countMouseStats(from: data)
            stats.mouseClickCount += mouseStats.left + mouseStats.right + mouseStats.middle + mouseStats.other
            stats.scrollCount += mouseStats.scroll
        }
        
        return stats
    }
    
    // MARK: - 数据管理
    
    /// 获取数据库大小
    func getDatabaseSize() -> Int64 {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return 0
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            print("Failed to get database size: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 格式化数据库大小
    func getFormattedDatabaseSize() -> String {
        let size = getDatabaseSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// 获取事件总数
    func getTotalEventCount() -> Int {
        var count = 0
        
        let compactRequest = NSFetchRequest<NSManagedObject>(entityName: "CompactEvent")
        do {
            let results = try viewContext.fetch(compactRequest)
            for obj in results {
                if let data = obj.value(forKey: "data") as? Data {
                    count += data.count / 4  // 每个事件 4 字节
                }
            }
        } catch {
            print("Failed to count compact events: \(error.localizedDescription)")
        }
        
        return count
    }
    
    /// 清除所有数据
    func clearAllData(completion: (() -> Void)? = nil) {
        let context = persistentContainer.newBackgroundContext()
        context.perform { [weak self] in
            let compactRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CompactEvent")
            let compactDelete = NSBatchDeleteRequest(fetchRequest: compactRequest)
            
            do {
                try context.execute(compactDelete)
                try context.save()
                
                // 清除缓存
                self?.cacheLock.lock()
                self?.compactDataCache.removeAll()
                self?.cacheLock.unlock()
                
                // 执行 VACUUM 回收磁盘空间
                self?.vacuumDatabase()
                
                print("All activity data cleared")
            } catch {
                print("Failed to clear data: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    /// 清除指定日期之前的数据
    func clearDataBefore(date: Date, completion: (() -> Void)? = nil) {
        let context = persistentContainer.newBackgroundContext()
        let cutoffDayTs = CompactEventCodec.dayTimestamp(for: date)
        
        context.perform { [weak self] in
            let compactRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CompactEvent")
            compactRequest.predicate = NSPredicate(format: "dayTimestamp < %d", cutoffDayTs)
            let compactDelete = NSBatchDeleteRequest(fetchRequest: compactRequest)
            
            do {
                try context.execute(compactDelete)
                try context.save()
                
                // 清除过期缓存
                self?.cacheLock.lock()
                self?.compactDataCache = self?.compactDataCache.filter { $0.key >= cutoffDayTs } ?? [:]
                self?.cacheLock.unlock()
                
                // 执行 VACUUM 回收磁盘空间
                self?.vacuumDatabase()
                
                print("Old activity data cleared")
            } catch {
                print("Failed to clear old data: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    /// 执行 VACUUM 命令回收 SQLite 磁盘空间
    private func vacuumDatabase() {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            print("Cannot find store URL for VACUUM")
            return
        }
        
        // 需要在没有活动连接的情况下执行 VACUUM
        // 使用直接的 SQLite 连接
        DispatchQueue.global(qos: .utility).async {
            var db: OpaquePointer?
            
            if sqlite3_open(storeURL.path, &db) == SQLITE_OK {
                var errMsg: UnsafeMutablePointer<CChar>?
                
                if sqlite3_exec(db, "VACUUM", nil, nil, &errMsg) == SQLITE_OK {
                    print("Database VACUUM completed successfully")
                } else {
                    if let errMsg = errMsg {
                        print("VACUUM failed: \(String(cString: errMsg))")
                        sqlite3_free(errMsg)
                    }
                }
                
                sqlite3_close(db)
            } else {
                print("Failed to open database for VACUUM")
            }
        }
    }
    
    // MARK: - 键盘热力图数据
    
    /// 获取按键统计（按 keyCode 分组）
    func getKeyCodeStatistics(from startDate: Date, to endDate: Date) -> [Int16: Int] {
        var keyStats: [Int16: Int] = [:]
        
        let compactData = getCompactData(from: startDate, to: endDate)
        for (_, data) in compactData {
            let stats = CompactEventCodec.countKeyStats(from: data)
            for (keyCode, count) in stats {
                keyStats[keyCode, default: 0] += count
            }
        }
        
        return keyStats
    }
    
    /// 获取今日按键统计
    func getTodayKeyStats() -> [Int16: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return getKeyCodeStatistics(from: startOfDay, to: endOfDay)
    }
    
    /// 获取本周按键统计
    func getWeekKeyStats() -> [Int16: Int] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        return getKeyCodeStatistics(from: startOfWeek, to: endOfWeek)
    }
    
    /// 获取本月按键统计
    func getMonthKeyStats() -> [Int16: Int] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return getKeyCodeStatistics(from: startOfMonth, to: endOfMonth)
    }
    
    // MARK: - 鼠标详细统计
    
    /// 鼠标统计数据结构
    struct MouseStats {
        var leftClickCount: Int = 0
        var rightClickCount: Int = 0
        var middleClickCount: Int = 0
        var scrollCount: Int = 0
        var otherClickCount: Int = 0
    }
    
    /// 获取鼠标统计
    func getMouseStatistics(from startDate: Date, to endDate: Date) -> MouseStats {
        var stats = MouseStats()
        
        let compactData = getCompactData(from: startDate, to: endDate)
        for (_, data) in compactData {
            let mouseStats = CompactEventCodec.countMouseStats(from: data)
            stats.leftClickCount += mouseStats.left
            stats.rightClickCount += mouseStats.right
            stats.middleClickCount += mouseStats.middle
            stats.scrollCount += mouseStats.scroll
            stats.otherClickCount += mouseStats.other
        }
        
        return stats
    }
    
    func getTodayMouseStats() -> MouseStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return getMouseStatistics(from: startOfDay, to: endOfDay)
    }
    
    func getWeekMouseStats() -> MouseStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        return getMouseStatistics(from: startOfWeek, to: endOfWeek)
    }
    
    func getMonthMouseStats() -> MouseStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return getMouseStatistics(from: startOfMonth, to: endOfMonth)
    }
    
    // MARK: - 手势详细统计（仅双指滚动可被捕获）
    
    /// 手势统计数据结构
    struct GestureStats {
        var scrollCount: Int = 0      // 双指滚动
    }
    
    /// 获取手势统计
    func getGestureStatistics(from startDate: Date, to endDate: Date) -> GestureStats {
        var stats = GestureStats()
        
        let compactData = getCompactData(from: startDate, to: endDate)
        for (_, data) in compactData {
            let mouseStats = CompactEventCodec.countMouseStats(from: data)
            stats.scrollCount += mouseStats.scroll
        }
        
        return stats
    }
    
    func getTodayGestureStats() -> GestureStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return getGestureStatistics(from: startOfDay, to: endOfDay)
    }
    
    func getWeekGestureStats() -> GestureStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
        return getGestureStatistics(from: startOfWeek, to: endOfWeek)
    }
    
    func getMonthGestureStats() -> GestureStats {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return getGestureStatistics(from: startOfMonth, to: endOfMonth)
    }
    
    // MARK: - 自定义时间范围查询
    
    func getKeyStats(from startDate: Date, to endDate: Date) -> [Int16: Int] {
        return getKeyCodeStatistics(from: startDate, to: endDate)
    }
    
    func getMouseStats(from startDate: Date, to endDate: Date) -> MouseStats {
        return getMouseStatistics(from: startDate, to: endDate)
    }
    
    func getGestureStats(from startDate: Date, to endDate: Date) -> GestureStats {
        return getGestureStatistics(from: startDate, to: endDate)
    }
    
    // MARK: - 时间轴热力图数据
    
    /// 时间段统计数据
    struct TimeSlotStats: Identifiable {
        let id = UUID()
        let startTime: Date
        let endTime: Date
        let count: Int
        let label: String
        let isFuture: Bool  // 标记是否为未来时间
        
        init(startTime: Date, endTime: Date, count: Int, label: String, isFuture: Bool = false) {
            self.startTime = startTime
            self.endTime = endTime
            self.count = count
            self.label = label
            self.isFuture = isFuture
        }
    }
    
    /// 获取时间轴热力图数据（根据格子数量动态切分）
    /// - Parameters:
    ///   - startDate: 开始时间
    ///   - endDate: 结束时间
    ///   - slotCount: 格子数量（根据UI宽度计算）
    ///   - currentTime: 当前时间（用于判断未来时间）
    func getTimelineHeatmapData(
        from startDate: Date,
        to endDate: Date,
        slotCount: Int,
        currentTime: Date = Date()
    ) -> [TimeSlotStats] {
        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0, slotCount > 0 else { return [] }
        
        // 根据格子数量计算每个格子的时间跨度
        let interval = duration / Double(slotCount)
        
        // 根据时间跨度决定标签格式
        let format: String
        if duration <= 86400 { // <= 1天
            format = "HH:mm"
        } else if duration <= 86400 * 7 { // <= 1周
            format = "E HH:mm"
        } else if duration <= 86400 * 31 { // <= 1月
            format = "MM/dd"
        } else {
            format = "MM/dd"
        }
        
        var slots: [TimeSlotStats] = []
        var currentStart = startDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "zh_CN")
        
        for _ in 0..<slotCount {
            let currentEnd = currentStart.addingTimeInterval(interval)
            
            // 判断是否为未来时间
            let isFuture = currentStart >= currentTime
            
            // 查询这个时间段的事件数（未来时间不查询）
            let count = isFuture ? 0 : getKeyboardEventCount(from: currentStart, to: min(currentEnd, currentTime))
            
            let label = dateFormatter.string(from: currentStart)
            slots.append(TimeSlotStats(
                startTime: currentStart,
                endTime: currentEnd,
                count: count,
                label: label,
                isFuture: isFuture
            ))
            
            currentStart = currentEnd
        }
        
        return slots
    }
    
    /// 获取键盘事件数量
    private func getKeyboardEventCount(from startDate: Date, to endDate: Date) -> Int {
        guard startDate < endDate else { return 0 }
        
        var count = 0
        
        let compactData = getCompactData(from: startDate, to: endDate)
        for (dayTs, data) in compactData {
            let dayStart = CompactEventCodec.dayStart(from: dayTs)
            count += CompactEventCodec.countKeyboardEvents(
                from: data,
                dayStart: dayStart,
                startTime: startDate,
                endTime: endDate
            )
        }
        
        return count
    }
    
    // MARK: - 时间范围辅助方法
    
    /// 获取今日的完整时间范围（0:00 - 24:00）
    func getTodayFullRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return (startOfDay, endOfDay)
    }
    
    /// 获取本周的完整时间范围（周一 0:00 - 周日 24:00）
    func getWeekFullRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        // 获取本周周一
        var startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        // 确保是周一（某些地区周日是一周的开始）
        if calendar.component(.weekday, from: startOfWeek) != 2 {
            startOfWeek = calendar.date(bySetting: .weekday, value: 2, of: startOfWeek) ?? startOfWeek
        }
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        return (startOfWeek, endOfWeek)
    }
    
    /// 获取本月的完整时间范围（1日 0:00 - 月末 24:00）
    func getMonthFullRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return (startOfMonth, endOfMonth)
    }
}

