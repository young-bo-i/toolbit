import SwiftUI

@main
struct ToolbitApp: App {
    @StateObject private var updateManager = UpdateManager.shared
    @State private var showUpdateView = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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
                Button("关于 Toolbit") {
                    showUpdateView = true
                }
            }
            
            // 添加检查更新菜单
            CommandGroup(after: .appInfo) {
                Divider()
                
                Button("检查更新...") {
                    showUpdateView = true
                    Task {
                        await updateManager.checkForUpdates()
                    }
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
                
                Button("访问 GitHub 主页") {
                    updateManager.openHomePage()
                }
            }
        }
        
        // 设置窗口
        Settings {
            SettingsView()
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    
    var body: some View {
        Form {
            Section("更新设置") {
                Toggle("启动时自动检查更新", isOn: Binding(
                    get: { updateManager.autoCheckEnabled },
                    set: { updateManager.setAutoCheck($0) }
                ))
            }
            
            Section("关于") {
                LabeledContent("版本", value: updateManager.currentVersion)
                LabeledContent("构建", value: updateManager.currentBuild)
                
                if let lastCheck = updateManager.lastCheckDate {
                    LabeledContent("上次检查更新", value: lastCheck.formatted())
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 200)
    }
}
