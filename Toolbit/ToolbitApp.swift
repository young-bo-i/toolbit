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
                Button {
                    // 手动检查更新
                    Task {
                        await updateManager.manualCheckForUpdates()
                    }
                } label: {
                    if updateManager.isManualChecking {
                        Text(updateManager.manualCheckingStatus)
                    } else {
                        Text(L10n.menuCheckUpdate)
                    }
                }
                .keyboardShortcut("U", modifiers: [.command, .shift])
                .disabled(updateManager.isManualChecking)
            }
        }
        
        // 设置窗口
        Settings {
            SettingsView()
                .id(languageManager.refreshID)
        }
        
        // 关于窗口（只显示应用信息，不再显示更新内容）
        Window(L10n.menuAbout, id: "about") {
            AboutView()
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
        TabView {
            // 通用设置
            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
            
            // AI 设置
            AISettingsView()
                .tabItem {
                    Label("AI 模型", systemImage: "brain")
                }
            
            // 更新设置
            UpdateSettingsView()
                .tabItem {
                    Label("更新", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 550, height: 450)
    }
}

// MARK: - 通用设置
struct GeneralSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        Form {
            Section {
                Picker(L10n.settingsLanguage, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .onChange(of: languageManager.currentLanguage) { _, _ in
                    languageManager.setLanguage(languageManager.currentLanguage)
                }
            } header: {
                Text(L10n.settingsLanguageTitle)
            } footer: {
                Text(L10n.settingsRestartHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AI 设置
struct AISettingsView: View {
    @StateObject var aiConfig = AIConfigManager.shared
    @State private var showApiKey = false
    @State private var testResult: String?
    @State private var isTesting = false
    
    var body: some View {
        Form {
            // 启用开关
            Section {
                Toggle("启用 AI 功能", isOn: $aiConfig.isEnabled)
            } header: {
                Text("AI 功能")
            } footer: {
                Text("启用后，部分工具将支持 AI 辅助功能")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 模型配置
            Section {
                // 预设模型选择
                Picker("预设模型", selection: Binding(
                    get: { 
                        AIConfigManager.PresetModel.presets.first { $0.id == aiConfig.modelId } 
                            ?? AIConfigManager.PresetModel.presets.last!
                    },
                    set: { preset in
                        aiConfig.applyPreset(preset)
                    }
                )) {
                    ForEach(AIConfigManager.PresetModel.presets) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                
                // API 端点
                TextField("API 端点", text: $aiConfig.endpoint, prompt: Text("https://api.openai.com/v1"))
                    .textFieldStyle(.roundedBorder)
                
                // 模型编码
                TextField("模型编码", text: $aiConfig.modelId, prompt: Text("gpt-4"))
                    .textFieldStyle(.roundedBorder)
                
                // API 密钥
                HStack {
                    if showApiKey {
                        TextField("API 密钥", text: $aiConfig.apiKey, prompt: Text("sk-..."))
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API 密钥", text: $aiConfig.apiKey, prompt: Text("sk-..."))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("模型配置")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("配置数据保存在本地，更新应用后不会丢失")
                    if !aiConfig.isConfigured {
                        Text("⚠️ 请填写完整的配置信息")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            // 操作按钮
            Section {
                HStack {
                    Button("测试连接") {
                        Task {
                            isTesting = true
                            testResult = nil
                            let result = await aiConfig.testConnection()
                            switch result {
                            case .success(let message):
                                testResult = "✅ \(message)"
                            case .failure(let error):
                                testResult = "❌ \(error.localizedDescription)"
                            }
                            isTesting = false
                        }
                    }
                    .disabled(!aiConfig.isConfigured || isTesting)
                    
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.leading, 8)
                    }
                    
                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .padding(.leading, 8)
                    }
                    
                    Spacer()
                    
                    Button("重置配置", role: .destructive) {
                        aiConfig.reset()
                        testResult = nil
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 更新设置
struct UpdateSettingsView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    
    var body: some View {
        Form {
            Section {
                Toggle(L10n.settingsAutoCheck, isOn: Binding(
                    get: { updateManager.autoCheckEnabled },
                    set: { updateManager.setAutoCheck($0) }
                ))
                
                HStack {
                    Text("当前版本")
                    Spacer()
                    Text("v\(updateManager.currentVersion)")
                        .foregroundStyle(.secondary)
                }
                
                if let lastCheck = updateManager.lastCheckDate {
                    HStack {
                        Text("上次检查")
                        Spacer()
                        Text(lastCheck.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(L10n.settingsUpdate)
            }
            
            Section {
                Button("立即检查更新") {
                    Task {
                        await updateManager.manualCheckForUpdates()
                    }
                }
                .disabled(updateManager.isManualChecking)
                
                Button("访问 GitHub") {
                    updateManager.openHomePage()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
