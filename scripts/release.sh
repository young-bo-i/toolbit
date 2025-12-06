#!/bin/bash

# =============================================================================
# Toolbit 自动发布脚本
# 
# 功能：
#   - 自动获取当前最新版本号
#   - 支持自动递增版本号（patch/minor/major）
#   - 提交代码并创建 tag
#   - 推送到 GitHub 触发自动构建
#
# 使用方法：
#   ./scripts/release.sh          # 自动递增 patch 版本 (1.0.0 -> 1.0.1)
#   ./scripts/release.sh patch    # 递增 patch 版本 (1.0.0 -> 1.0.1)
#   ./scripts/release.sh minor    # 递增 minor 版本 (1.0.0 -> 1.1.0)
#   ./scripts/release.sh major    # 递增 major 版本 (1.0.0 -> 2.0.0)
#   ./scripts/release.sh 1.2.3    # 指定版本号
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 切换到项目根目录
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

info "项目目录: $PROJECT_ROOT"

# 检查是否有未提交的更改
check_git_status() {
    if [[ -n $(git status -s) ]]; then
        warning "检测到未提交的更改："
        git status -s
        echo ""
        read -p "是否要提交这些更改？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "请输入 commit 信息: " commit_msg
            git add -A
            git commit -m "$commit_msg"
            success "更改已提交"
        else
            error "请先处理未提交的更改"
        fi
    fi
}

# 获取当前最新版本号
get_current_version() {
    # 从 git tag 获取最新版本
    local latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    echo "${latest_tag#v}"
}

# 递增版本号
increment_version() {
    local version=$1
    local type=$2
    
    IFS='.' read -r major minor patch <<< "$version"
    
    case $type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch|*)
            patch=$((patch + 1))
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# 验证版本号格式
validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "无效的版本号格式: $version (应为 x.y.z 格式)"
    fi
}

# 更新项目中的版本号
update_project_version() {
    local version=$1
    
    info "更新项目版本号为: $version"
    
    # 更新 Cask 文件中的版本号（可选，因为 CI 会自动更新）
    # sed -i '' "s/version \".*\"/version \"$version\"/" Casks/toolbit.rb
    
    # 如果有 Info.plist，也可以更新
    # if [ -f "Toolbit/Info.plist" ]; then
    #     /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" Toolbit/Info.plist
    # fi
}

# 创建并推送 tag
create_and_push_tag() {
    local version=$1
    local tag="v$version"
    
    # 先同步远程代码（避免 CI 更新 Cask 后产生冲突）
    info "同步远程代码..."
    git fetch origin main
    
    # 检查是否需要 rebase
    local local_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/main)
    
    if [ "$local_commit" != "$remote_commit" ]; then
        info "检测到远程有更新，正在同步..."
        git pull --rebase origin main || error "同步失败，请手动处理冲突"
    fi
    
    # 检查 tag 是否已存在
    if git rev-parse "$tag" >/dev/null 2>&1; then
        warning "Tag $tag 已存在"
        read -p "是否要删除并重新创建？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "删除本地 tag: $tag"
            git tag -d "$tag" 2>/dev/null || true
            
            info "删除远程 tag: $tag"
            git push origin ":refs/tags/$tag" 2>/dev/null || true
        else
            error "取消发布"
        fi
    fi
    
    info "创建 tag: $tag"
    git tag "$tag"
    
    # 只有本地有新提交时才推送代码
    local_commit=$(git rev-parse HEAD)
    remote_commit=$(git rev-parse origin/main)
    
    if [ "$local_commit" != "$remote_commit" ]; then
        info "推送代码到远程..."
        git push origin main
    else
        info "本地代码与远程一致，跳过代码推送"
    fi
    
    info "推送 tag 到远程..."
    git push origin "$tag"
    
    success "Tag $tag 已推送，GitHub Actions 将自动开始构建"
}

# 主函数
main() {
    echo ""
    echo "========================================"
    echo "       Toolbit 自动发布脚本"
    echo "========================================"
    echo ""
    
    # 检查 git 状态
    check_git_status
    
    # 获取当前版本
    local current_version=$(get_current_version)
    info "当前版本: $current_version"
    
    # 确定新版本号
    local new_version=""
    local input="${1:-patch}"
    
    case $input in
        patch|minor|major)
            new_version=$(increment_version "$current_version" "$input")
            info "版本类型: $input"
            ;;
        *)
            # 假设是指定的版本号
            validate_version "$input"
            new_version="$input"
            ;;
    esac
    
    info "新版本: $new_version"
    echo ""
    
    # 确认发布
    read -p "确认发布 v$new_version？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warning "取消发布"
        exit 0
    fi
    
    # 更新版本号
    update_project_version "$new_version"
    
    # 创建并推送 tag
    create_and_push_tag "$new_version"
    
    echo ""
    echo "========================================"
    success "发布完成！"
    echo "========================================"
    echo ""
    echo "查看构建进度："
    echo "  https://github.com/young-bo-i/toolbit/actions"
    echo ""
    echo "查看 Release："
    echo "  https://github.com/young-bo-i/toolbit/releases/tag/v$new_version"
    echo ""
}

# 运行主函数
main "$@"

