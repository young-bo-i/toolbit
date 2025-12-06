# Homebrew Cask 配方文件
# 
# 使用方法：
# 1. 创建 homebrew-toolbit 仓库（或直接使用本仓库的 Casks 目录）
# 2. 安装命令：
#    brew tap young-bo-i/toolbit https://github.com/young-bo-i/toolbit.git
#    brew install --cask toolbit
#
# 更新命令：
#    brew upgrade --cask toolbit

cask "toolbit" do
  version "1.0.5"
  sha256 "9066d7e07dddec37ada00f700efa2afabc7754716a0ee1b9768de93e0c0992d3"  # 由 GitHub Actions 自动更新

  url "https://github.com/young-bo-i/toolbit/releases/download/v#{version}/Toolbit-#{version}.zip",
      verified: "github.com/young-bo-i/toolbit/"
  name "Toolbit"
  name "开发百宝箱"
  desc "Developer toolbox with various utilities for daily development"
  homepage "https://github.com/young-bo-i/toolbit"

  # 自动更新检测 - 从 GitHub Releases 获取最新版本
  livecheck do
    url :url
    strategy :github_latest
  end

  # 依赖 macOS 版本 (Ventura 13.0+)
  depends_on macos: ">= :ventura"

  # 安装应用
  app "Toolbit.app"

  # 安装后提示
  postflight do
    # 移除隔离属性，避免首次打开时的安全提示
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Toolbit.app"],
                   sudo: false
  end

  # 卸载时清理
  uninstall quit: "com.toolbit.app"

  # 彻底清理（zap）
  zap trash: [
    "~/Library/Preferences/com.toolbit.app.plist",
    "~/Library/Caches/com.toolbit.app",
    "~/Library/Application Support/Toolbit",
    "~/Library/Saved Application State/com.toolbit.app.savedState",
  ]
end
