import Foundation
import CoreData

// MARK: - 事件类型枚举（使用 Int16 存储以节省空间）
enum ActivityEventType: Int16, CaseIterable {
    // 键盘事件
    case keyDown = 1
    
    // 鼠标事件
    case leftMouseDown = 10
    case rightMouseDown = 11
    case otherMouseDown = 12
    
    // 触摸板事件（只有双指滚动可被捕获）
    case scroll = 20
    
    var displayName: String {
        switch self {
        case .keyDown: return "按键按下"
        case .leftMouseDown: return "左键点击"
        case .rightMouseDown: return "右键点击"
        case .otherMouseDown: return "其他按键"
        case .scroll: return "滚动"
        }
    }
    
    var icon: String {
        switch self {
        case .keyDown: return "keyboard"
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: return "computermouse"
        case .scroll: return "hand.draw"
        }
    }
    
    // 事件分类
    var category: EventCategory {
        switch self {
        case .keyDown:
            return .keyboard
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return .mouse
        case .scroll:
            return .trackpad
        }
    }
}

// MARK: - 事件分类
enum EventCategory: String, CaseIterable {
    case keyboard = "keyboard"
    case mouse = "mouse"
    case trackpad = "trackpad"
    
    var displayName: String {
        switch self {
        case .keyboard: return "键盘"
        case .mouse: return "鼠标"
        case .trackpad: return "触摸板"
        }
    }
    
    var icon: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouse: return "computermouse"
        case .trackpad: return "hand.draw"
        }
    }
}

// MARK: - 轻量事件结构体（用于内存缓冲）
// 优化：移除不必要的字段，大幅减少存储空间
struct RawEventData {
    let timestamp: Date
    let eventType: ActivityEventType
    let keyCode: Int16       // 仅键盘事件使用
    let mouseButton: Int16   // 仅鼠标事件使用（区分中键和其他按键）
    
    init(
        eventType: ActivityEventType,
        keyCode: Int16 = 0,
        mouseButton: Int16 = 0
    ) {
        self.timestamp = Date()
        self.eventType = eventType
        self.keyCode = keyCode
        self.mouseButton = mouseButton
    }
    
    // 转换为字典（用于批量插入）
    func toDictionary() -> [String: Any] {
        return [
            "timestamp": timestamp,
            "eventType": eventType.rawValue,
            "keyCode": keyCode,
            "mouseButton": mouseButton
        ]
    }
}

// MARK: - 统计数据模型
struct ActivityStats {
    let startDate: Date
    let endDate: Date
    
    // 按事件类型统计
    var keyboardCount: Int = 0
    var mouseClickCount: Int = 0
    var scrollCount: Int = 0
    
    // 总计
    var totalCount: Int {
        keyboardCount + mouseClickCount + scrollCount
    }
}

// MARK: - 时间段统计
struct TimeRangeStats: Identifiable {
    let id = UUID()
    let hour: Int
    var count: Int = 0
}

