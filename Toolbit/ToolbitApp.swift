import SwiftUI

@main
struct ToolbitApp: App {
    @StateObject private var updateManager = UpdateManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var showUpdateView = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(languageManager.refreshID) // 语言切换时刷新整个视图
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
                                showUpdateView = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showUpdateView) {
                    UpdateView()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // 应用菜单
            CommandGroup(replacing: .appInfo) {
                Button(L10n.menuAbout) {
                    showUpdateView = true
                }
            }
            
            // 添加检查更新菜单
            CommandGroup(after: .appInfo) {
                Button(L10n.menuCheckUpdate) {
                    showUpdateView = true
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
            
            Section(L10n.settingsAbout) {
                LabeledContent(L10n.settingsVersion, value: updateManager.currentVersion)
                LabeledContent(L10n.settingsBuild, value: updateManager.currentBuild)
                
                if let lastCheck = updateManager.lastCheckDate {
                    LabeledContent(L10n.settingsLastCheck, value: lastCheck.formatted())
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
