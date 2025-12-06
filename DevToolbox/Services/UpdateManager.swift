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

// MARK: - 更新状态
enum UpdateStatus: Equatable {
    case idle
    case checking
    case available(version: String, downloadUrl: String, releaseNotes: String)
    case noUpdate
    case downloading(progress: Double)
    case readyToInstall(localPath: URL)
    case error(message: String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.noUpdate, .noUpdate):
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
                // 查找 .dmg 或 .zip 文件
                if let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }) {
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
        alert.informativeText = "DMG 文件已打开。请将新版本的 DevToolbox 拖动到「应用程序」文件夹中替换旧版本，然后重新打开应用。"
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
        let tempDir = FileManager.default.temporaryDirectory
        let extractDir = tempDir.appendingPathComponent("DevToolbox_Update")
        
        do {
            // 清理旧的解压目录
            if FileManager.default.fileExists(atPath: extractDir.path) {
                try FileManager.default.removeItem(at: extractDir)
            }
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            
            // 解压 ZIP
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipPath.path, "-d", extractDir.path]
            try process.run()
            process.waitUntilExit()
            
            // 查找 .app 文件
            let contents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
                status = .error(message: "解压后未找到应用程序")
                return
            }
            
            // 获取当前应用路径
            let currentAppPath = Bundle.main.bundleURL
            let applicationsPath = URL(fileURLWithPath: "/Applications/DevToolbox.app")
            
            // 确定目标路径
            let targetPath: URL
            if currentAppPath.path.hasPrefix("/Applications") {
                targetPath = currentAppPath
            } else {
                targetPath = applicationsPath
            }
            
            // 创建安装脚本
            let scriptPath = tempDir.appendingPathComponent("install_update.sh")
            let script = """
            #!/bin/bash
            sleep 1
            rm -rf "\(targetPath.path)"
            cp -R "\(appURL.path)" "\(targetPath.path)"
            xattr -cr "\(targetPath.path)"
            open "\(targetPath.path)"
            rm -rf "\(extractDir.path)"
            rm -f "\(zipPath.path)"
            """
            
            try script.write(to: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
            
            // 执行安装脚本
            let installProcess = Process()
            installProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            installProcess.arguments = [scriptPath.path]
            try installProcess.run()
            
            // 退出当前应用
            NSApplication.shared.terminate(nil)
            
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
        
        // 默认开启自动检查
        if UserDefaults.standard.object(forKey: "autoCheckUpdates") == nil {
            autoCheckEnabled = true
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(autoCheckEnabled, forKey: "autoCheckUpdates")
        if let date = lastCheckDate {
            UserDefaults.standard.set(date, forKey: "lastUpdateCheck")
        }
    }
    
    func setAutoCheck(_ enabled: Bool) {
        autoCheckEnabled = enabled
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
