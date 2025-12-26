import Foundation
import CoreData

// MARK: - 活动数据管理器
class ActivityDataManager {
    static let shared = ActivityDataManager()
    
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
    
    // MARK: - 批量插入
    func batchInsert(_ events: [RawEventData]) {
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            // 使用批量插入请求（iOS 13+ / macOS 10.15+）
            let batchInsert = NSBatchInsertRequest(
                entity: NSEntityDescription.entity(forEntityName: "ActivityEvent", in: context)!,
                objects: events.map { $0.toDictionary() }
            )
            batchInsert.resultType = .count
            
            do {
                let result = try context.execute(batchInsert) as? NSBatchInsertResult
                if let count = result?.result as? Int {
                    print("Batch inserted \(count) events")
                }
            } catch {
                // 降级为普通插入
                print("Batch insert failed, falling back to regular insert: \(error.localizedDescription)")
                for event in events {
                    let entity = NSEntityDescription.insertNewObject(forEntityName: "ActivityEvent", into: context)
                    entity.setValue(event.timestamp, forKey: "timestamp")
                    entity.setValue(event.eventType.rawValue, forKey: "eventType")
                    entity.setValue(event.keyCode, forKey: "keyCode")
                    entity.setValue(event.mouseButton, forKey: "mouseButton")
                }
                try? context.save()
            }
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
        
        let context = viewContext
        
        // 获取各类型事件数量
        stats.keyboardCount = getEventCount(from: startDate, to: endDate, types: [.keyDown], context: context)
        stats.mouseClickCount = getEventCount(from: startDate, to: endDate, types: [.leftMouseDown, .rightMouseDown, .otherMouseDown], context: context)
        stats.scrollCount = getEventCount(from: startDate, to: endDate, types: [.scroll], context: context)
        
        return stats
    }
    
    /// 获取事件数量
    private func getEventCount(from startDate: Date, to endDate: Date, types: [ActivityEventType], context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "ActivityEvent")
        request.resultType = .countResultType
        
        let typeValues = types.map { NSNumber(value: $0.rawValue) }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startDate as NSDate, endDate as NSDate),
            NSPredicate(format: "eventType IN %@", typeValues)
        ])
        
        do {
            return try context.count(for: request)
        } catch {
            print("Failed to count events: \(error.localizedDescription)")
            return 0
        }
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
        let request = NSFetchRequest<NSNumber>(entityName: "ActivityEvent")
        request.resultType = .countResultType
        
        do {
            return try viewContext.count(for: request)
        } catch {
            print("Failed to count total events: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// 清除所有数据
    func clearAllData(completion: (() -> Void)? = nil) {
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ActivityEvent")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
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
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "ActivityEvent")
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", date as NSDate)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
                print("Old activity data cleared")
            } catch {
                print("Failed to clear old data: \(error.localizedDescription)")
            }
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    // MARK: - 键盘热力图数据
    
    /// 获取按键统计（按 keyCode 分组）
    func getKeyCodeStatistics(from startDate: Date, to endDate: Date) -> [Int16: Int] {
        var keyStats: [Int16: Int] = [:]
        
        let request = NSFetchRequest<NSDictionary>(entityName: "ActivityEvent")
        request.resultType = .dictionaryResultType
        
        // 按 keyCode 分组统计
        let keyCodeExpr = NSExpression(forKeyPath: "keyCode")
        let countExpr = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "timestamp")])
        
        let keyCodeDesc = NSExpressionDescription()
        keyCodeDesc.name = "keyCode"
        keyCodeDesc.expression = keyCodeExpr
        keyCodeDesc.expressionResultType = .integer16AttributeType
        
        let countDesc = NSExpressionDescription()
        countDesc.name = "count"
        countDesc.expression = countExpr
        countDesc.expressionResultType = .integer64AttributeType
        
        request.propertiesToFetch = [keyCodeDesc, countDesc]
        request.propertiesToGroupBy = ["keyCode"]
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startDate as NSDate, endDate as NSDate),
            NSPredicate(format: "eventType == %d", ActivityEventType.keyDown.rawValue)
        ])
        
        do {
            let results = try viewContext.fetch(request)
            for result in results {
                if let keyCode = result["keyCode"] as? Int16,
                   let count = result["count"] as? Int {
                    keyStats[keyCode] = count
                }
            }
        } catch {
            print("Failed to fetch key statistics: \(error.localizedDescription)")
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
        let context = viewContext
        
        // 左键点击
        stats.leftClickCount = getEventCount(from: startDate, to: endDate, types: [.leftMouseDown], context: context)
        
        // 右键点击
        stats.rightClickCount = getEventCount(from: startDate, to: endDate, types: [.rightMouseDown], context: context)
        
        // 滚动
        stats.scrollCount = getEventCount(from: startDate, to: endDate, types: [.scroll], context: context)
        
        // 其他按键（包括中键）
        stats.otherClickCount = getEventCount(from: startDate, to: endDate, types: [.otherMouseDown], context: context)
        
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
        let context = viewContext
        stats.scrollCount = getEventCount(from: startDate, to: endDate, types: [.scroll], context: context)
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
        
        let request = NSFetchRequest<NSNumber>(entityName: "ActivityEvent")
        request.resultType = .countResultType
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startDate as NSDate, endDate as NSDate),
            NSPredicate(format: "eventType == %d", ActivityEventType.keyDown.rawValue)
        ])
        
        do {
            return try viewContext.count(for: request)
        } catch {
            print("Failed to count keyboard events: \(error.localizedDescription)")
            return 0
        }
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

