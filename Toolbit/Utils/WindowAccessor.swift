import SwiftUI
import AppKit

/*
 自定义顶部工具栏
 
 功能：在顶部同时实现无边框的纯文案 + 有边框的按钮
 
 使用方法：
 ```swift
 NavigationSplitView { ... }
     .customToolbar(title: "标题文案") {
         // 按钮点击事件
         print("设置按钮被点击")
     }
 ```
 
 原理：
 - SwiftUI 的 toolbar 中所有内容都会有边框（macOS 系统行为）
 - 通过 AppKit 的 NSToolbar，设置 NSToolbarItem.isBordered = false 实现无边框文本
 - 标题文本放在中间，按钮放在右边
 */

// MARK: - 工具栏项标识符
extension NSToolbarItem.Identifier {
    static let titleLabel = NSToolbarItem.Identifier("titleLabel")
    static let flexibleSpace = NSToolbarItem.Identifier.flexibleSpace
    static let settingsButton = NSToolbarItem.Identifier("settingsButton")
}

// MARK: - 自定义工具栏管理器
class CustomToolbarManager: NSObject, NSToolbarDelegate {
    static let shared = CustomToolbarManager()
    
    private var titleText: String = ""
    private var onSettingsClick: (() -> Void)?
    private weak var currentWindow: NSWindow?
    private var isConfigured = false
    
    private override init() {
        super.init()
    }
    
    /// 配置工具栏
    func configure(window: NSWindow?, title: String, onSettingsClick: (() -> Void)? = nil) {
        guard let window = window else { return }
        
        self.titleText = title
        self.onSettingsClick = onSettingsClick
        
        // 如果已经配置过这个窗口，只更新标题
        if isConfigured && currentWindow === window {
            updateTitle(title)
            return
        }
        
        // 如果窗口已经有我们的工具栏，不要重复创建
        if let existingToolbar = window.toolbar, existingToolbar.identifier == "MainToolbar" {
            updateTitle(title)
            return
        }
        
        // 创建新工具栏
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        
        window.toolbar = toolbar
        currentWindow = window
        isConfigured = true
    }
    
    /// 更新标题
    func updateTitle(_ title: String) {
        self.titleText = title
        // 找到标题项并更新
        if let toolbar = currentWindow?.toolbar,
           let item = toolbar.items.first(where: { $0.itemIdentifier == .titleLabel }),
           let label = item.view as? NSTextField {
            label.stringValue = title
        }
    }
    
    // MARK: - NSToolbarDelegate
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .titleLabel:
            return createTitleItem()
        case .settingsButton:
            return createSettingsButton()
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .titleLabel, .flexibleSpace, .settingsButton]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.titleLabel, .flexibleSpace, .settingsButton]
    }
    
    // MARK: - 创建工具栏项
    
    /// 创建无边框的标题文本
    private func createTitleItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .titleLabel)
        
        let label = NSTextField(labelWithString: titleText)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.labelColor
        label.alignment = .center
        label.isBordered = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.backgroundColor = .clear
        
        item.view = label
        item.isBordered = false  // 关键：无边框
        
        return item
    }
    
    /// 创建设置按钮（有边框）
    private func createSettingsButton() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .settingsButton)
        
        // 安全创建图标
        let image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置") ?? NSImage(named: NSImage.actionTemplateName)!
        let button = NSButton(image: image, target: self, action: #selector(settingsClicked))
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        
        item.view = button
        item.isBordered = true  // 有边框
        item.label = "设置"
        item.toolTip = "设置"
        
        return item
    }
    
    @objc private func settingsClicked() {
        onSettingsClick?()
    }
}

// MARK: - SwiftUI 视图修饰符
struct CustomToolbarModifier: ViewModifier {
    let title: String
    let onSettingsClick: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    CustomToolbarManager.shared.configure(
                        window: window,
                        title: title,
                        onSettingsClick: onSettingsClick
                    )
                }
            )
    }
}

extension View {
    /// 添加自定义工具栏（无边框标题 + 有边框按钮）
    func customToolbar(title: String, onSettingsClick: (() -> Void)? = nil) -> some View {
        modifier(CustomToolbarModifier(title: title, onSettingsClick: onSettingsClick))
    }
}

// MARK: - Window Accessor
struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 延迟执行，确保窗口已经准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.callback(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 不在 updateNSView 中重复调用，避免循环
    }
}


