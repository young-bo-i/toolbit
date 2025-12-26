import Foundation
import AppKit
import CoreGraphics

// MARK: - 活动监控器
class ActivityMonitor: ObservableObject {
    static let shared = ActivityMonitor()
    
    @Published var isMonitoring = false
    @Published var hasPermission = false
    
    // 实时统计（内存中的计数，用于即时显示）
    @Published var realtimeKeyStats: [Int16: Int] = [:]
    @Published var realtimeLeftClickCount: Int = 0
    @Published var realtimeRightClickCount: Int = 0
    @Published var realtimeMiddleClickCount: Int = 0
    @Published var realtimeScrollCount: Int = 0
    @Published var realtimeOtherClickCount: Int = 0
    
    // 手势实时统计（注意：macOS 限制，只有双指滚动可以被捕获）
    @Published var realtimeGestureScrollCount: Int = 0
    
    // 数据更新通知（用于触发视图刷新）
    @Published var lastUpdateTime: Date = Date()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // 手势事件监控器
    private var gestureMonitors: [Any] = []
    
    // 事件缓冲区
    private var eventBuffer: [RawEventData] = []
    private let bufferLock = NSLock()
    private let batchSize = 100  // 减小批量大小，更快写入
    private let flushInterval: TimeInterval = 2.0  // 缩短刷新间隔
    private var flushTimer: Timer?
    
    // 权限检查定时器
    private var permissionCheckTimer: Timer?
    
    // UI 更新节流（避免过于频繁的 UI 更新）
    private var uiUpdateThrottleTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.5  // 500ms 更新一次 UI
    
    // 滚动节流器
    private var scrollThrottler = ScrollThrottler()
    
    // 监控的事件类型
    // 修饰键状态追踪（避免重复计数）
    private var lastModifierFlags: CGEventFlags = []
    
    private let eventMask: CGEventMask = {
        var mask: CGEventMask = 0
        
        // 键盘事件
        mask |= (1 << CGEventType.keyDown.rawValue)
        mask |= (1 << CGEventType.flagsChanged.rawValue)  // 修饰键：Shift, Control, Option, Command
        
        // 鼠标事件
        mask |= (1 << CGEventType.leftMouseDown.rawValue)
        mask |= (1 << CGEventType.rightMouseDown.rawValue)
        mask |= (1 << CGEventType.otherMouseDown.rawValue)
        
        // 滚轮/触摸板滚动事件
        mask |= (1 << CGEventType.scrollWheel.rawValue)
        
        return mask
    }()
    
    private init() {
        checkPermission()
        loadTodayStats()
    }
    
    deinit {
        stopMonitoring()
        stopPermissionCheckTimer()
        stopGestureMonitors()
    }
    
    // MARK: - 权限检查
    func checkPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        // 在主线程更新状态
        DispatchQueue.main.async {
            self.hasPermission = trusted
        }
    }
    
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        
        // 启动权限检查定时器
        startPermissionCheckTimer()
    }
    
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
        // 启动权限检查定时器
        startPermissionCheckTimer()
    }
    
    /// 启动权限检查定时器
    private func startPermissionCheckTimer() {
        // 先停止已有的定时器
        stopPermissionCheckTimer()
        
        // 在主线程创建定时器
        DispatchQueue.main.async {
            self.permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
                let trusted = AXIsProcessTrustedWithOptions(options)
                
                if trusted {
                    self.hasPermission = true
                    self.stopPermissionCheckTimer()
                    print("Accessibility permission granted!")
                }
            }
        }
    }
    
    /// 停止权限检查定时器
    private func stopPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    // MARK: - 监控控制
    func startMonitoring() {
        guard hasPermission else {
            requestPermission()
            return
        }
        
        guard !isMonitoring else { return }
        
        // 创建事件回调
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            
            let monitor = Unmanaged<ActivityMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handleEvent(type: type, event: event)
            
            return Unmanaged.passUnretained(event)
        }
        
        // 创建事件监听
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap")
            return
        }
        
        // 添加到运行循环
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // 启动定时刷新
        startFlushTimer()
        
        // 启动手势监控
        startGestureMonitors()
        
        isMonitoring = true
        
        // 保存监控状态
        UserDefaults.standard.set(true, forKey: "ActivityMonitorEnabled")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        // 停止定时器
        flushTimer?.invalidate()
        flushTimer = nil
        
        // 刷新剩余数据
        flush()
        
        // 停止事件监听
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        // 停止手势监控
        stopGestureMonitors()
        
        eventTap = nil
        runLoopSource = nil
        isMonitoring = false
        
        // 保存监控状态
        UserDefaults.standard.set(false, forKey: "ActivityMonitorEnabled")
    }
    
    // MARK: - 手势监控
    // 注意：macOS 系统限制，大部分触控板手势（捏合、旋转、轻扫等）被系统拦截
    // 用于 Mission Control、切换桌面等系统功能，无法被第三方应用捕获
    // 只有双指滚动（scrollWheel）可以被可靠地捕获
    
    private func startGestureMonitors() {
        // 由于 macOS 限制，手势监控功能有限
        // 双指滚动已通过 CGEventTap 的 scrollWheel 事件捕获
    }
    
    private func stopGestureMonitors() {
        for monitor in gestureMonitors {
            NSEvent.removeMonitor(monitor)
        }
        gestureMonitors.removeAll()
    }
    
    // MARK: - 事件处理
    private func handleEvent(type: CGEventType, event: CGEvent) {
        var rawEvent: RawEventData?
        var shouldUpdateUI = false
        
        switch type {
        case .keyDown:
            let keyCode = Int16(event.getIntegerValueField(.keyboardEventKeycode))
            rawEvent = RawEventData(
                eventType: .keyDown,
                keyCode: keyCode
            )
            // 实时更新按键统计
            DispatchQueue.main.async {
                self.realtimeKeyStats[keyCode, default: 0] += 1
            }
            shouldUpdateUI = true
            
        case .flagsChanged:
            // 处理修饰键：Shift, Control, Option, Command, Fn, Caps Lock
            let flags = event.flags
            let keyCode = Int16(event.getIntegerValueField(.keyboardEventKeycode))
            
            // 检测哪个修饰键被按下（通过比较前后状态）
            // 修饰键的 keyCode:
            // 56 = Left Shift, 60 = Right Shift
            // 59 = Left Control, 62 = Right Control
            // 58 = Left Option, 61 = Right Option
            // 55 = Left Command, 54 = Right Command
            // 57 = Caps Lock
            // 63 = Fn
            
            // 只在按下时记录（不记录释放）
            let modifierKeyCodes: Set<Int16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(keyCode) {
                // 检查是按下还是释放
                let isPressed = isModifierPressed(keyCode: keyCode, flags: flags)
                if isPressed {
                    rawEvent = RawEventData(
                        eventType: .keyDown,
                        keyCode: keyCode
                    )
                    DispatchQueue.main.async {
                        self.realtimeKeyStats[keyCode, default: 0] += 1
                    }
                    shouldUpdateUI = true
                }
            }
            lastModifierFlags = flags
            
        case .leftMouseDown:
            rawEvent = RawEventData(
                eventType: .leftMouseDown,
                mouseButton: 0
            )
            DispatchQueue.main.async {
                self.realtimeLeftClickCount += 1
            }
            shouldUpdateUI = true
            
        case .rightMouseDown:
            rawEvent = RawEventData(
                eventType: .rightMouseDown,
                mouseButton: 1
            )
            DispatchQueue.main.async {
                self.realtimeRightClickCount += 1
            }
            shouldUpdateUI = true
            
        case .otherMouseDown:
            let buttonNumber = Int16(event.getIntegerValueField(.mouseEventButtonNumber))
            rawEvent = RawEventData(
                eventType: .otherMouseDown,
                mouseButton: buttonNumber
            )
            DispatchQueue.main.async {
                if buttonNumber == 2 {
                    self.realtimeMiddleClickCount += 1
                } else {
                    self.realtimeOtherClickCount += 1
                }
            }
            shouldUpdateUI = true
            
        case .scrollWheel:
            let deltaX = event.getDoubleValueField(.scrollWheelEventDeltaAxis2)
            let deltaY = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            
            // 使用节流器判断是否记录
            if scrollThrottler.shouldRecord(deltaX: deltaX, deltaY: deltaY) {
                rawEvent = RawEventData(
                    eventType: .scroll
                )
                DispatchQueue.main.async {
                    self.realtimeScrollCount += 1
                }
                shouldUpdateUI = true
            }
            
        default:
            break
        }
        
        if let rawEvent = rawEvent {
            enqueue(rawEvent)
        }
        
        // 节流 UI 更新
        if shouldUpdateUI {
            let now = CACurrentMediaTime()
            if now - uiUpdateThrottleTime >= uiUpdateInterval {
                uiUpdateThrottleTime = now
                DispatchQueue.main.async {
                    self.lastUpdateTime = Date()
                }
            }
        }
    }
    
    // MARK: - 缓冲区管理
    private func enqueue(_ event: RawEventData) {
        bufferLock.lock()
        eventBuffer.append(event)
        let count = eventBuffer.count
        bufferLock.unlock()
        
        if count >= batchSize {
            flush()
        }
    }
    
    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }
    
    func flush() {
        bufferLock.lock()
        guard !eventBuffer.isEmpty else {
            bufferLock.unlock()
            return
        }
        let events = eventBuffer
        eventBuffer.removeAll()
        bufferLock.unlock()
        
        // 在后台队列执行批量插入
        DispatchQueue.global(qos: .utility).async {
            ActivityDataManager.shared.batchInsert(events)
        }
    }
    
    // MARK: - 加载历史数据到实时统计
    private func loadTodayStats() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 加载键盘统计
            let keyStats = ActivityDataManager.shared.getTodayKeyStats()
            let mouseStats = ActivityDataManager.shared.getTodayMouseStats()
            let gestureStats = ActivityDataManager.shared.getTodayGestureStats()
            
            DispatchQueue.main.async {
                self?.realtimeKeyStats = keyStats
                self?.realtimeLeftClickCount = mouseStats.leftClickCount
                self?.realtimeRightClickCount = mouseStats.rightClickCount
                self?.realtimeMiddleClickCount = mouseStats.middleClickCount
                self?.realtimeScrollCount = mouseStats.scrollCount
                self?.realtimeOtherClickCount = mouseStats.otherClickCount
                
                // 手势统计
                self?.realtimeGestureScrollCount = gestureStats.scrollCount
                
                self?.lastUpdateTime = Date()
            }
        }
    }
    
    func refreshTodayStats() {
        loadTodayStats()
    }
    
    /// 重置实时统计（用于切换时间范围时）
    func resetRealtimeStats() {
        realtimeKeyStats = [:]
        realtimeLeftClickCount = 0
        realtimeRightClickCount = 0
        realtimeMiddleClickCount = 0
        realtimeScrollCount = 0
        realtimeOtherClickCount = 0
        realtimeGestureScrollCount = 0
        lastUpdateTime = Date()
    }
    
    // MARK: - 辅助方法
    
    /// 判断修饰键是否被按下
    private func isModifierPressed(keyCode: Int16, flags: CGEventFlags) -> Bool {
        switch keyCode {
        case 56, 60: // Left/Right Shift
            return flags.contains(.maskShift)
        case 59, 62: // Left/Right Control
            return flags.contains(.maskControl)
        case 58, 61: // Left/Right Option
            return flags.contains(.maskAlternate)
        case 54, 55: // Left/Right Command
            return flags.contains(.maskCommand)
        case 57: // Caps Lock
            return flags.contains(.maskAlphaShift)
        case 63: // Fn
            return flags.contains(.maskSecondaryFn)
        default:
            return false
        }
    }
}

// MARK: - 滚动节流器
class ScrollThrottler {
    private var lastRecordTime: TimeInterval = 0
    private var accumulatedDeltaX: Double = 0
    private var accumulatedDeltaY: Double = 0
    
    let throttleInterval: TimeInterval = 0.1  // 100ms
    let deltaThreshold: Double = 50.0
    
    func shouldRecord(deltaX: Double, deltaY: Double) -> Bool {
        accumulatedDeltaX += abs(deltaX)
        accumulatedDeltaY += abs(deltaY)
        
        let now = CACurrentMediaTime()
        let shouldRecord = (now - lastRecordTime >= throttleInterval) ||
                          (accumulatedDeltaX >= deltaThreshold) ||
                          (accumulatedDeltaY >= deltaThreshold)
        
        if shouldRecord {
            lastRecordTime = now
            accumulatedDeltaX = 0
            accumulatedDeltaY = 0
        }
        return shouldRecord
    }
}


