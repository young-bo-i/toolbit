# Homebrew Cask 配方文件
# 
# 使用方法：
# 1. 创建 homebrew-toolbit 仓库
# 2. 将此文件放入 Casks 目录
# 3. 更新 version 和 sha256
#
# 安装命令：
# brew tap young-bo-i/toolbit
# brew install --cask toolbit

cask "toolbit" do
  version "1.0.0"
  sha256 "YOUR_SHA256_HERE"  # 需要替换为实际的 SHA256

  url "https://github.com/young-bo-i/toolbit/releases/download/v#{version}/DevToolbox-#{version}.zip"
  name "Toolbit"
  name "开发百宝箱"
  desc "Developer toolbox with various utilities for daily development"
  homepage "https://github.com/young-bo-i/toolbit"

  # 依赖 macOS 版本
  depends_on macos: ">= :sonoma"

  app "DevToolbox.app"

  zap trash: [
    "~/Library/Preferences/com.devtools.DevToolbox.plist",
    "~/Library/Caches/com.devtools.DevToolbox",
    "~/Library/Application Support/DevToolbox",
  ]
end

