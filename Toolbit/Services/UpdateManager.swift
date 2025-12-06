import Foundation
import AppKit

// MARK: - GitHub Release 模型
struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String
    let htmlUrl: String
    let publishedAt: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let browserDownloadUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - 更新方式
enum UpdateMethod: String, CaseIterable {
    case homebrew = "Homebrew"
    case directDownload = "直接下载"
    
    var description: String {
        switch self {
        case .homebrew:
            return "通过 Homebrew Cask 更新（推荐）"
        case .directDownload:
            return "直接下载安装包更新"
        }
    }
}

// MARK: - 更新状态
enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(version: String, downloadUrl: String, releaseNotes: String)
    case noUpdate
    case downloading(progress: Double)
    case readyToInstall(localPath: URL)
    case installing  // 正在自动安装
    case installingViaHomebrew
    case homebrewSuccess
    case installSuccess  // 自动安装成功
    case error(message: String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.noUpdate, .noUpdate),
             (.installingViaHomebrew, .installingViaHomebrew), (.homebrewSuccess, .homebrewSuccess),
             (.installing, .installing), (.installSuccess, .installSuccess):
            return true
        case let (.available(v1, _, _), .available(v2, _, _)):
            return v1 == v2
        case let (.downloading(p1), .downloading(p2)):
            return p1 == p2
        case let (.readyToInstall(u1), .readyToInstall(u2)):
            return u1 == u2
        case let (.error(m1), .error(m2)):
            return m1 == m2
        default:
            return false
        }
    }
}

// MARK: - 更新管理器
@MainActor
class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    // GitHub 仓库配置
    private let githubOwner = "young-bo-i"
    private let githubRepo = "toolbit"
    
    @Published var status: UpdateStatus = .idle
    @Published var lastCheckDate: Date?
    @Published var autoCheckEnabled: Bool = true
    @Published var preferredUpdateMethod: UpdateMethod = .homebrew
    @Published var isHomebrewInstalled: Bool = false
    @Published var isInstalledViaHomebrew: Bool = false
    
    // 当前版本
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var downloadTask: URLSessionDownloadTask?
    private var observation: NSKeyValueObservation?
    
    private init() {
        loadSettings()
        checkHomebrewStatus()
    }
    
    // MARK: - 检查 Homebrew 状态
    private func checkHomebrewStatus() {
        Task {
            // 检查 Homebrew 是否安装
            let homebrewExists = checkCommandExists("/opt/homebrew/bin/brew")
            let usrLocalBrewExists = checkCommandExists("/usr/local/bin/brew")
            isHomebrewInstalled = homebrewExists || usrLocalBrewExists
            
            // 检查是否通过 Homebrew 安装
            if isHomebrewInstalled {
                isInstalledViaHomebrew = await checkInstalledViaHomebrew()
            }
        }
    }
    
    private func checkCommandExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    private func checkInstalledViaHomebrew() async -> Bool {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "brew list --cask | grep -q toolbit"]
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    // MARK: - 检查更新
    func checkForUpdates() async {
        status = .checking
        
        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"
        
        guard let url = URL(string: urlString) else {
            status = .error(message: "无效的更新地址")
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                status = .error(message: "网络响应错误")
                return
            }
            
            if httpResponse.statusCode == 404 {
                status = .error(message: "未找到发布版本，请先在 GitHub 创建 Release")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                status = .error(message: "服务器错误: \(httpResponse.statusCode)")
                return
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            lastCheckDate = Date()
            saveSettings()
            
            // 解析版本号（去掉 v 前缀）
            let latestVersion = release.tagName.hasPrefix("v") 
                ? String(release.tagName.dropFirst()) 
                : release.tagName
            
            // 比较版本
            if isNewerVersion(latestVersion, than: currentVersion) {
                // 优先查找 .zip 文件（支持自动安装），其次 .dmg
                let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") })
                let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
                
                if let asset = zipAsset ?? dmgAsset {
                    status = .available(
                        version: latestVersion,
                        downloadUrl: asset.browserDownloadUrl,
                        releaseNotes: release.body
                    )
                } else {
                    status = .error(message: "未找到可下载的安装包")
                }
            } else {
                status = .noUpdate
            }
        } catch {
            status = .error(message: "检查更新失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 下载更新
    func downloadUpdate(from urlString: String) {
        guard let url = URL(string: urlString) else {
            status = .error(message: "无效的下载地址")
            return
        }
        
        status = .downloading(progress: 0)
        
        let session = URLSession(configuration: .default)
        downloadTask = session.downloadTask(with: url) { [weak self] localURL, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.status = .error(message: "下载失败: \(error.localizedDescription)")
                    return
                }
                
                guard let localURL = localURL else {
                    self?.status = .error(message: "下载文件不存在")
                    return
                }
                
                // 移动到临时目录
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = url.lastPathComponent
                let destinationURL = tempDir.appendingPathComponent(fileName)
                
                do {
                    // 删除已存在的文件
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    self?.status = .readyToInstall(localPath: destinationURL)
                } catch {
                    self?.status = .error(message: "保存文件失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 监听下载进度
        observation = downloadTask?.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.status = .downloading(progress: progress.fractionCompleted)
            }
        }
        
        downloadTask?.resume()
    }
    
    // MARK: - 安装更新
    func installUpdate(from localPath: URL) {
        let fileExtension = localPath.pathExtension.lowercased()
        
        if fileExtension == "dmg" {
            installFromDMG(localPath)
        } else if fileExtension == "zip" {
            installFromZip(localPath)
        } else {
            status = .error(message: "不支持的安装包格式")
        }
    }
    
    private func installFromDMG(_ dmgPath: URL) {
        // 打开 DMG 文件
        NSWorkspace.shared.open(dmgPath)
        
        // 显示安装说明
        let alert = NSAlert()
        alert.messageText = "安装更新"
        alert.informativeText = "DMG 文件已打开。请将新版本的 Toolbit 拖动到「应用程序」文件夹中替换旧版本，然后重新打开应用。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.addButton(withTitle: "打开应用程序文件夹")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        }
        
        // 退出当前应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func installFromZip(_ zipPath: URL) {
        status = .installing
        
        let tempDir = FileManager.default.temporaryDirectory
        let extractDir = tempDir.appendingPathComponent("Toolbit_Update")
        
        do {
            // 清理旧的解压目录
            if FileManager.default.fileExists(atPath: extractDir.path) {
                try FileManager.default.removeItem(at: extractDir)
            }
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            
            // 先移除 ZIP 文件的隔离属性
            let xattrZipProcess = Process()
            xattrZipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrZipProcess.arguments = ["-cr", zipPath.path]
            try? xattrZipProcess.run()
            xattrZipProcess.waitUntilExit()
            
            // 解压 ZIP
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-o", zipPath.path, "-d", extractDir.path]
            unzipProcess.standardOutput = nil
            unzipProcess.standardError = nil
            try unzipProcess.run()
            unzipProcess.waitUntilExit()
            
            // 查找 .app 文件
            let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
                status = .error(message: "解压后未找到应用程序")
                return
            }
            
            // 立即移除解压后 app 的隔离属性
            let xattrAppProcess = Process()
            xattrAppProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrAppProcess.arguments = ["-cr", appURL.path]
            try? xattrAppProcess.run()
            xattrAppProcess.waitUntilExit()
            
            // 获取当前应用路径和 PID
            let currentAppPath = Bundle.main.bundleURL
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let applicationsPath = URL(fileURLWithPath: "/Applications/Toolbit.app")
            
            // 确定目标路径 - 优先使用当前应用路径
            let targetPath: URL
            if currentAppPath.path.hasPrefix("/Applications") {
                targetPath = currentAppPath
            } else {
                // 如果不在 Applications，安装到 Applications
                targetPath = applicationsPath
            }
            
            // 创建安装脚本 - 使用 PID 等待当前应用退出
            let scriptPath = tempDir.appendingPathComponent("install_update.sh")
            let logPath = tempDir.appendingPathComponent("install_update.log")
            let script = """
            #!/bin/bash
            exec > "\(logPath.path)" 2>&1
            echo "开始安装更新..."
            echo "当前 PID: \(currentPID)"
            echo "目标路径: \(targetPath.path)"
            echo "源路径: \(appURL.path)"
            
            # 等待当前应用完全退出（最多等待 10 秒）
            for i in {1..20}; do
                if ! kill -0 \(currentPID) 2>/dev/null; then
                    echo "应用已退出"
                    break
                fi
                echo "等待应用退出... ($i)"
                sleep 0.5
            done
            
            # 再等待一下确保文件句柄释放
            sleep 0.5
            
            # 删除旧版本
            echo "删除旧版本..."
            rm -rf "\(targetPath.path)"
            
            # 复制新版本
            echo "复制新版本..."
            cp -R "\(appURL.path)" "\(targetPath.path)"
            
            # 移除隔离属性
            echo "移除隔离属性..."
            xattr -cr "\(targetPath.path)" 2>/dev/null || true
            xattr -d com.apple.quarantine "\(targetPath.path)" 2>/dev/null || true
            
            # 启动新版本
            echo "启动新版本..."
            sleep 0.3
            open "\(targetPath.path)"
            
            # 清理临时文件
            echo "清理临时文件..."
            rm -rf "\(extractDir.path)"
            rm -f "\(zipPath.path)"
            
            echo "安装完成！"
            
            # 延迟删除脚本自身
            sleep 2
            rm -f "\(scriptPath.path)"
            rm -f "\(logPath.path)"
            """
            
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
            
            // 使用 nohup 在后台执行安装脚本，确保脚本不会因为父进程退出而终止
            let installProcess = Process()
            installProcess.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            installProcess.arguments = ["/bin/bash", scriptPath.path]
            installProcess.standardOutput = nil
            installProcess.standardError = nil
            installProcess.currentDirectoryURL = tempDir
            try installProcess.run()
            
            // 显示成功状态，然后强制退出
            status = .installSuccess
            
            // 使用 exit() 强制退出，确保应用一定会关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // 先尝试正常退出
                NSApplication.shared.terminate(nil)
                
                // 如果 terminate 被阻止，强制退出
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    exit(0)
                }
            }
            
        } catch {
            status = .error(message: "安装失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 取消下载
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        observation = nil
        status = .idle
    }
    
    // MARK: - Homebrew 更新
    func updateViaHomebrew() {
        status = .installingViaHomebrew
        
        Task {
            do {
                // 先更新 tap
                let tapResult = await runBrewCommand(["tap", "young-bo-i/toolbit", "https://github.com/young-bo-i/toolbit.git"])
                if !tapResult.success {
                    // tap 可能已存在，继续执行
                    print("Tap result: \(tapResult.output)")
                }
                
                // 更新 Homebrew
                let updateResult = await runBrewCommand(["update"])
                print("Update result: \(updateResult.output)")
                
                // 升级应用
                let upgradeResult = await runBrewCommand(["upgrade", "--cask", "toolbit"])
                
                if upgradeResult.success {
                    status = .homebrewSuccess
                    // 提示用户重启应用
                    showRestartAlert()
                } else if upgradeResult.output.contains("already installed") {
                    status = .noUpdate
                } else {
                    status = .error(message: "Homebrew 更新失败: \(upgradeResult.output)")
                }
            }
        }
    }
    
    func installViaHomebrew() {
        status = .installingViaHomebrew
        
        Task {
            // 添加 tap
            let tapResult = await runBrewCommand(["tap", "young-bo-i/toolbit", "https://github.com/young-bo-i/toolbit.git"])
            print("Tap result: \(tapResult.output)")
            
            // 安装应用
            let installResult = await runBrewCommand(["install", "--cask", "toolbit"])
            
            if installResult.success {
                status = .homebrewSuccess
                showRestartAlert()
            } else {
                status = .error(message: "Homebrew 安装失败: \(installResult.output)")
            }
        }
    }
    
    private func runBrewCommand(_ arguments: [String]) async -> (success: Bool, output: String) {
        let process = Process()
        let pipe = Pipe()
        
        // 查找 brew 路径
        let brewPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") 
            ? "/opt/homebrew/bin/brew" 
            : "/usr/local/bin/brew"
        
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        // 设置环境变量
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        process.environment = env
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (process.terminationStatus == 0, output)
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    private func showRestartAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "更新完成"
            alert.informativeText = "应用已通过 Homebrew 更新成功。请重新启动应用以使用新版本。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "立即重启")
            alert.addButton(withTitle: "稍后重启")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.restartApp()
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
    
    // MARK: - 版本比较
    private func isNewerVersion(_ newVersion: String, than currentVersion: String) -> Bool {
        let newComponents = newVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(newComponents.count, currentComponents.count)
        
        for i in 0..<maxLength {
            let new = i < newComponents.count ? newComponents[i] : 0
            let current = i < currentComponents.count ? currentComponents[i] : 0
            
            if new > current {
                return true
            } else if new < current {
                return false
            }
        }
        
        return false
    }
    
    // MARK: - 设置持久化
    private func loadSettings() {
        autoCheckEnabled = UserDefaults.standard.bool(forKey: "autoCheckUpdates")
        if let date = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date {
            lastCheckDate = date
        }
        
        // 加载更新方式偏好
        if let methodRaw = UserDefaults.standard.string(forKey: "preferredUpdateMethod"),
           let method = UpdateMethod(rawValue: methodRaw) {
            preferredUpdateMethod = method
        }
        
        // 默认开启自动检查
        if UserDefaults.standard.object(forKey: "autoCheckUpdates") == nil {
            autoCheckEnabled = true
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(autoCheckEnabled, forKey: "autoCheckUpdates")
        UserDefaults.standard.set(preferredUpdateMethod.rawValue, forKey: "preferredUpdateMethod")
        if let date = lastCheckDate {
            UserDefaults.standard.set(date, forKey: "lastUpdateCheck")
        }
    }
    
    func setAutoCheck(_ enabled: Bool) {
        autoCheckEnabled = enabled
        saveSettings()
    }
    
    func setPreferredUpdateMethod(_ method: UpdateMethod) {
        preferredUpdateMethod = method
        saveSettings()
    }
    
    // MARK: - 打开 GitHub 页面
    func openReleasePage() {
        let urlString = "https://github.com/\(githubOwner)/\(githubRepo)/releases/latest"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openHomePage() {
        let urlString = "https://github.com/\(githubOwner)/\(githubRepo)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
