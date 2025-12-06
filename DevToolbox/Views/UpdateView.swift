import SwiftUI

struct UpdateView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showMethodPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标和标题
            VStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("开发百宝箱")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("版本 \(updateManager.currentVersion) (Build \(updateManager.currentBuild))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // 显示安装方式
                if updateManager.isInstalledViaHomebrew {
                    Label("已通过 Homebrew 安装", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.top, 20)
            
            Divider()
            
            // 更新状态
            statusView
            
            Spacer()
            
            // 操作按钮
            actionButtons
            
            // 设置
            settingsSection
        }
        .padding(24)
        .frame(width: 450, height: 550)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - 状态视图
    @ViewBuilder
    private var statusView: some View {
        switch updateManager.status {
        case .idle:
            idleView
            
        case .checking:
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("正在检查更新...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .available(let version, _, let releaseNotes):
            availableUpdateView(version: version, releaseNotes: releaseNotes)
            
        case .noUpdate:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("已是最新版本")
                    .font(.headline)
                if let lastCheck = updateManager.lastCheckDate {
                    Text("上次检查: \(lastCheck.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .downloading(let progress):
            VStack(spacing: 16) {
                ProgressView(value: progress) {
                    Text("正在下载更新...")
                }
                .progressViewStyle(.linear)
                
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .monospacedDigit()
                
                Button("取消") {
                    updateManager.cancelDownload()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .readyToInstall(let localPath):
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("更新已下载完成")
                    .font(.headline)
                
                Text("点击「安装更新」将关闭应用并安装新版本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("安装更新") {
                    updateManager.installUpdate(from: localPath)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("检查更新失败")
                    .font(.headline)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .installingViaHomebrew:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text("正在通过 Homebrew 更新...")
                    .font(.headline)
                
                Text("请稍候，这可能需要一些时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .homebrewSuccess:
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                
                Text("更新成功！")
                    .font(.headline)
                
                Text("请重新启动应用以使用新版本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - 空闲视图
    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("点击下方按钮检查更新")
                .foregroundStyle(.secondary)
            
            if let lastCheck = updateManager.lastCheckDate {
                Text("上次检查: \(lastCheck.formatted())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 可用更新视图
    private func availableUpdateView(version: String, releaseNotes: String) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("发现新版本!")
                        .font(.headline)
                    Text("v\(version)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            
            // 更新说明
            VStack(alignment: .leading, spacing: 8) {
                Text("更新说明:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView {
                    Text(releaseNotes.isEmpty ? "暂无更新说明" : releaseNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - 操作按钮
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("访问 GitHub") {
                updateManager.openHomePage()
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            switch updateManager.status {
            case .available(_, let downloadUrl, _):
                // 更新方式选择
                if updateManager.isHomebrewInstalled {
                    Menu {
                        Button {
                            updateManager.updateViaHomebrew()
                        } label: {
                            Label("通过 Homebrew 更新", systemImage: "cup.and.saucer.fill")
                        }
                        
                        Button {
                            updateManager.downloadUpdate(from: downloadUrl)
                        } label: {
                            Label("直接下载更新", systemImage: "arrow.down.circle.fill")
                        }
                    } label: {
                        Label("更新", systemImage: "arrow.down.app.fill")
                    }
                    .menuStyle(.borderedButton)
                    .fixedSize()
                } else {
                    Button("下载更新") {
                        updateManager.downloadUpdate(from: downloadUrl)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
            case .checking, .downloading, .installingViaHomebrew:
                EmptyView()
                
            case .homebrewSuccess:
                Button("重启应用") {
                    restartApp()
                }
                .buttonStyle(.borderedProminent)
                
            default:
                Button("检查更新") {
                    Task {
                        await updateManager.checkForUpdates()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    // MARK: - 设置区域
    private var settingsSection: some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Toggle("启动时自动检查更新", isOn: Binding(
                    get: { updateManager.autoCheckEnabled },
                    set: { updateManager.setAutoCheck($0) }
                ))
                .font(.caption)
                
                Spacer()
                
                if updateManager.isHomebrewInstalled {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(.brown)
                        Text("Homebrew 可用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Homebrew 安装提示
            if !updateManager.isHomebrewInstalled {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("推荐使用 Homebrew 安装以获得更好的更新体验")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("了解更多") {
                        if let url = URL(string: "https://brew.sh") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .font(.caption2)
                    .buttonStyle(.link)
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview {
    UpdateView()
}

