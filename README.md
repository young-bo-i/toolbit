# Toolbit (开发百宝箱)

一款为开发者打造的 macOS 原生工具箱应用，集成多种常用开发工具。

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ 功能特性

### 📝 文本工具
- **字符统计** - 统计文本中的字符、单词、行数等
- **字符串对比** - 对比两段文本的差异（类似 VSCode Diff）
- **转义/反转义** - 对特殊字符进行转义和反转义处理
- **Markdown 预览** - 实时预览 Markdown 文档

### 🔄 编解码器
- **Base64 文本** - 文本的 Base64 编码与解码
- **URL 编解码** - URL 百分号编码与解码
- **二维码** - 生成和识别二维码
- **SVG 转图片** - 将 SVG 代码转换为 PNG 图片
- **Base64 图片** - 图片与 Base64 编码互转

### 📋 格式化工具
- **JSON** - 格式化和美化 JSON 数据
- **SQL** - 格式化和美化 SQL 语句（支持多种方言）
- **XML** - 格式化和美化 XML 数据

### 🖼️ 图片工具
- **OCR 文字识别** - 从图片中识别并提取文字

## 📥 安装

### 方式一：Homebrew（推荐）

```bash
# 添加 tap 并安装
brew tap young-bo-i/toolbit https://github.com/young-bo-i/toolbit.git
brew install --cask toolbit
```

### 方式二：手动下载

1. 前往 [Releases](https://github.com/young-bo-i/toolbit/releases) 页面
2. 下载最新版本的 `.dmg` 或 `.zip` 文件
3. 打开 DMG，将 Toolbit 拖入「应用程序」文件夹
4. 首次打开需要在「系统设置 → 隐私与安全性」中允许运行

## 🔄 更新

### Homebrew 更新（推荐）

```bash
# 更新到最新版本
brew upgrade --cask toolbit
```

### 应用内更新

应用内置自动更新检查功能：
- 🔔 启动时自动检查更新
- ⌨️ 菜单栏 → Toolbit → 检查更新（⇧⌘U）
- 📦 发现新版本后支持两种更新方式：
  - **Homebrew 更新**：如果已安装 Homebrew，可直接通过 Homebrew 更新
  - **直接下载**：下载安装包手动更新

### 更新流程说明

```
┌─────────────────┐
│  检查 GitHub    │
│  Releases API   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  比较版本号     │
│  (语义化版本)   │
└────────┬────────┘
         │
    有新版本?
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐  ┌───────────┐
│无更新 │  │ 提示更新  │
└───────┘  └─────┬─────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
   ┌──────────┐   ┌──────────┐
   │ Homebrew │   │ 直接下载 │
   │   更新   │   │   安装   │
   └──────────┘   └──────────┘
```

## 🛠️ 开发

### 环境要求
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### 构建项目

```bash
# 克隆仓库
git clone https://github.com/young-bo-i/toolbit.git
cd toolbit

# 使用 Xcode 打开
open Toolbit.xcodeproj

# 或使用命令行构建
xcodebuild -project Toolbit.xcodeproj -scheme Toolbit -configuration Debug build
```

### 发布新版本

1. 更新版本号
2. 创建并推送 tag：
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
3. GitHub Actions 会自动构建并创建 Release

## 📝 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
