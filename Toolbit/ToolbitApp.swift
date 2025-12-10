import SwiftUI

@main
struct ToolbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updateManager = UpdateManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        // 主窗口 - 单窗口模式
        Window("Toolbit", id: "main") {
            ContentView()
                .id(languageManager.refreshID)
                .environment(\.languageRefreshID, languageManager.refreshID)
                .onAppear {
                    // 启动时自动检查更新
                    if updateManager.autoCheckEnabled {
                        Task {
                            // 延迟 2 秒检查，避免影响启动速度
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            await updateManager.checkForUpdates()
                            
                            // 如果有新版本，显示更新窗口
                            if case .available = updateManager.status {
                                openWindow(id: "about")
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 禁用新建窗口
            CommandGroup(replacing: .newItem) { }
            
            // 应用菜单
            CommandGroup(replacing: .appInfo) {
                Button(L10n.menuAbout) {
                    openWindow(id: "about")
                }
            }
            
            // 添加检查更新菜单
            CommandGroup(after: .appInfo) {
                Button(L10n.menuCheckUpdate) {
                    openWindow(id: "about")
                    Task {
                        await updateManager.checkForUpdates()
                    }
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
            }
        }
        
        // 设置窗口
        Settings {
            SettingsView()
                .id(languageManager.refreshID)
        }
        
        // 关于/更新窗口
        Window(L10n.menuAbout, id: "about") {
            UpdateView()
                .id(languageManager.refreshID)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 禁止多窗口
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 点击 Dock 图标时，如果没有可见窗口，显示主窗口
        if !flag {
            for window in sender.windows {
                if window.identifier?.rawValue == "main" {
                    window.makeKeyAndOrderFront(nil)
                    return false
                }
            }
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭最后一个窗口时不退出应用
        return false
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        Form {
            Section(L10n.settingsLanguageTitle) {
                Picker(L10n.settingsLanguage, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: languageManager.currentLanguage) { _, _ in
                    languageManager.setLanguage(languageManager.currentLanguage)
                }
                
                Text(L10n.settingsRestartHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(L10n.settingsUpdate) {
                Toggle(L10n.settingsAutoCheck, isOn: Binding(
                    get: { updateManager.autoCheckEnabled },
                    set: { updateManager.setAutoCheck($0) }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
