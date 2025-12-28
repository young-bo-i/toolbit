import Foundation

// MARK: - 压缩事件存储
// 设计目标：将每个事件从 ~20 bytes 压缩到 ~4 bytes
//
// 压缩策略：
// 1. 时间戳：不存储完整时间戳，而是存储"当天秒数"(0-86399)，用 17 bits
// 2. 事件类型：用 4 bits (0-15)
// 3. keyCode/mouseButton：用 7 bits (0-127，足够覆盖所有按键)
// 4. 保留位：4 bits（未来扩展）
//
// 总计：32 bits = 4 bytes per event
//
// 每天的事件打包成一个 Binary blob 存储，按天索引

/// 压缩事件编码器/解码器
struct CompactEventCodec {
    
    // MARK: - 单个事件编码 (4 bytes)
    // 格式: [秒数 17bits][事件类型 4bits][keyCode/button 7bits][保留 4bits]
    
    /// 将事件编码为 4 字节
    static func encode(secondsOfDay: UInt32, eventType: ActivityEventType, keyOrButton: Int16) -> UInt32 {
        var packed: UInt32 = 0
        
        // 秒数 (17 bits, max 131071, 我们只用 0-86399)
        packed |= (secondsOfDay & 0x1FFFF) << 15
        
        // 事件类型 (4 bits)
        packed |= (UInt32(eventType.rawValue) & 0xF) << 11
        
        // keyCode 或 mouseButton (7 bits, max 127)
        packed |= (UInt32(keyOrButton) & 0x7F) << 4
        
        // 保留 4 bits 为 0
        
        return packed
    }
    
    /// 从 4 字节解码事件
    static func decode(_ packed: UInt32) -> (secondsOfDay: UInt32, eventType: Int16, keyOrButton: Int16) {
        let secondsOfDay = (packed >> 15) & 0x1FFFF
        let eventType = Int16((packed >> 11) & 0xF)
        let keyOrButton = Int16((packed >> 4) & 0x7F)
        
        return (secondsOfDay, eventType, keyOrButton)
    }
    
    // MARK: - 批量编码
    
    /// 将多个事件编码为 Data
    static func encodeEvents(_ events: [RawEventData], dayStart: Date) -> Data {
        var data = Data(capacity: events.count * 4)
        
        for event in events {
            let secondsOfDay = UInt32(event.timestamp.timeIntervalSince(dayStart))
            let keyOrButton = event.eventType == .keyDown ? event.keyCode : event.mouseButton
            
            let packed = encode(
                secondsOfDay: min(secondsOfDay, 86399), // 确保不超过一天
                eventType: event.eventType,
                keyOrButton: keyOrButton
            )
            
            // 写入 4 字节（大端序，便于排序）
            withUnsafeBytes(of: packed.bigEndian) { data.append(contentsOf: $0) }
        }
        
        return data
    }
    
    /// 从 Data 解码事件
    static func decodeEvents(_ data: Data, dayStart: Date) -> [(timestamp: Date, eventType: ActivityEventType, keyOrButton: Int16)] {
        var events: [(Date, ActivityEventType, Int16)] = []
        events.reserveCapacity(data.count / 4)
        
        var offset = 0
        while offset + 4 <= data.count {
            let packed = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            
            let (secondsOfDay, eventTypeRaw, keyOrButton) = decode(packed)
            
            if let eventType = ActivityEventType(rawValue: eventTypeRaw) {
                let timestamp = dayStart.addingTimeInterval(TimeInterval(secondsOfDay))
                events.append((timestamp, eventType, keyOrButton))
            }
            
            offset += 4
        }
        
        return events
    }
    
    // MARK: - 辅助方法
    
    /// 获取日期对应的天时间戳（当天 0:00 的 Unix 时间戳，用于索引）
    static func dayTimestamp(for date: Date) -> Int32 {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return Int32(startOfDay.timeIntervalSince1970)
    }
    
    /// 从天时间戳获取当天起始时间
    static func dayStart(from dayTimestamp: Int32) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(dayTimestamp))
    }
}

// MARK: - 压缩统计查询

extension CompactEventCodec {
    
    /// 从压缩数据中统计按键次数
    static func countKeyStats(from data: Data) -> [Int16: Int] {
        var stats: [Int16: Int] = [:]
        
        var offset = 0
        while offset + 4 <= data.count {
            let packed = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            
            let (_, eventTypeRaw, keyOrButton) = decode(packed)
            
            // 只统计键盘事件
            if eventTypeRaw == ActivityEventType.keyDown.rawValue {
                stats[keyOrButton, default: 0] += 1
            }
            
            offset += 4
        }
        
        return stats
    }
    
    /// 从压缩数据中统计鼠标事件
    static func countMouseStats(from data: Data) -> (left: Int, right: Int, middle: Int, scroll: Int, other: Int) {
        var left = 0, right = 0, middle = 0, scroll = 0, other = 0
        
        var offset = 0
        while offset + 4 <= data.count {
            let packed = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            
            let (_, eventTypeRaw, keyOrButton) = decode(packed)
            
            switch eventTypeRaw {
            case ActivityEventType.leftMouseDown.rawValue:
                left += 1
            case ActivityEventType.rightMouseDown.rawValue:
                right += 1
            case ActivityEventType.otherMouseDown.rawValue:
                if keyOrButton == 2 {
                    middle += 1
                } else {
                    other += 1
                }
            case ActivityEventType.scroll.rawValue:
                scroll += 1
            default:
                break
            }
            
            offset += 4
        }
        
        return (left, right, middle, scroll, other)
    }
    
    /// 统计指定时间范围内的键盘事件数量
    static func countKeyboardEvents(from data: Data, dayStart: Date, startTime: Date, endTime: Date) -> Int {
        let startSeconds = UInt32(max(0, startTime.timeIntervalSince(dayStart)))
        let endSeconds = UInt32(min(86400, endTime.timeIntervalSince(dayStart)))
        
        guard startSeconds < endSeconds else { return 0 }
        
        var count = 0
        var offset = 0
        
        while offset + 4 <= data.count {
            let packed = data.withUnsafeBytes { ptr -> UInt32 in
                ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            
            let (secondsOfDay, eventTypeRaw, _) = decode(packed)
            
            // 检查时间范围和事件类型
            if secondsOfDay >= startSeconds && secondsOfDay < endSeconds &&
               eventTypeRaw == ActivityEventType.keyDown.rawValue {
                count += 1
            }
            
            offset += 4
        }
        
        return count
    }
}

