import SwiftUI
import AppKit

/*
 自定义顶部工具栏
 
 功能：在顶部同时实现无边框的标题文案 + 搜索框
 
 使用方法：
 ```swift
 NavigationSplitView { ... }
     .customToolbar(title: "功能标题") { searchText in
         // 搜索回调
         print("搜索: \(searchText)")
     }
 ```
 
 原理：
 - SwiftUI 的 toolbar 中所有内容都会有边框（macOS 系统行为）
 - 通过 AppKit 的 NSToolbar，设置 NSToolbarItem.isBordered = false 实现无边框文本
 - 标题文本放在中间，搜索框放在右边
 */

// MARK: - 工具栏项标识符
extension NSToolbarItem.Identifier {
    static let titleLabel = NSToolbarItem.Identifier("titleLabel")
    static let flexibleSpace = NSToolbarItem.Identifier.flexibleSpace
    static let searchField = NSToolbarItem.Identifier("searchField")
}

// MARK: - 自定义工具栏管理器
class CustomToolbarManager: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
    static let shared = CustomToolbarManager()
    
    private var titleText: String = ""
    private var onSearch: ((String) -> Void)?
    private weak var currentWindow: NSWindow?
    private weak var searchField: NSSearchField?
    private weak var titleLabel: NSTextField?
    private var toolbarIdentifier = NSToolbar.Identifier("CustomToolbar_\(UUID().uuidString)")
    
    private override init() {
        super.init()
    }
    
    /// 配置工具栏
    func configure(window: NSWindow?, title: String, onSearch: ((String) -> Void)? = nil) {
        guard let window = window else { return }
        
        self.onSearch = onSearch
        
        // 如果是同一个窗口且已经有我们的工具栏，只更新标题
        if currentWindow === window, let toolbar = window.toolbar, toolbar.identifier == toolbarIdentifier {
            updateTitle(title)
            return
        }
        
        // 保存当前窗口
        currentWindow = window
        self.titleText = title
        
        // 移除旧的工具栏（如果有）
        if window.toolbar != nil {
            window.toolbar = nil
        }
        
        // 延迟创建新工具栏，确保旧的已经清理
        DispatchQueue.main.async { [weak self] in
            guard let self = self, window === self.currentWindow else { return }
            
            let toolbar = NSToolbar(identifier: self.toolbarIdentifier)
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false
            
            window.toolbar = toolbar
        }
    }
    
    /// 更新标题
    func updateTitle(_ title: String) {
        self.titleText = title
        titleLabel?.stringValue = title
    }
    
    // MARK: - NSToolbarDelegate
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .titleLabel:
            return createTitleItem()
        case .searchField:
            return createSearchField()
        default:
            return nil
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, .titleLabel, .flexibleSpace, .searchField]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.titleLabel, .flexibleSpace, .searchField]
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
        
        self.titleLabel = label
        
        return item
    }
    
    /// 创建搜索框
    private func createSearchField() -> NSToolbarItem {
        let item = NSSearchToolbarItem(itemIdentifier: .searchField)
        item.searchField.delegate = self
        item.searchField.placeholderString = "搜索工具..."
        self.searchField = item.searchField
        
        return item
    }
    
    // MARK: - NSSearchFieldDelegate
    
    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            onSearch?(searchField.stringValue)
        }
    }
}

// MARK: - SwiftUI 视图修饰符
struct CustomToolbarModifier: ViewModifier {
    let title: String
    let onSearch: ((String) -> Void)?
    
    func body(content: Content) -> some View {
        content
            .background(
                WindowAccessor { window in
                    CustomToolbarManager.shared.configure(
                        window: window,
                        title: title,
                        onSearch: onSearch
                    )
                }
            )
    }
}

extension View {
    /// 添加自定义工具栏（无边框标题 + 搜索框）
    func customToolbar(title: String, onSearch: ((String) -> Void)? = nil) -> some View {
        modifier(CustomToolbarModifier(title: title, onSearch: onSearch))
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


