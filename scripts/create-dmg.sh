#!/bin/bash

# =============================================================================
# 创建美化的 DMG 安装包
# =============================================================================

set -e

APP_NAME="Toolbit"
VERSION="${1:-1.0.0}"
APP_PATH="${2:-build/export/Toolbit.app}"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="build/${DMG_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"

# 临时目录
DMG_TEMP="build/dmg-temp"
DMG_BACKGROUND="scripts/dmg-resources/background.png"

echo "Creating DMG for ${APP_NAME} v${VERSION}..."

# 清理
rm -rf "${DMG_TEMP}"
rm -f "${DMG_PATH}"

# 创建临时目录
mkdir -p "${DMG_TEMP}"

# 复制应用
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# 创建 Applications 快捷方式
ln -s /Applications "${DMG_TEMP}/Applications"

# 检查是否有背景图
if [ -f "${DMG_BACKGROUND}" ]; then
    mkdir -p "${DMG_TEMP}/.background"
    cp "${DMG_BACKGROUND}" "${DMG_TEMP}/.background/background.png"
fi

# 计算 DMG 大小（应用大小 + 20MB 余量）
APP_SIZE=$(du -sm "${DMG_TEMP}" | cut -f1)
DMG_SIZE=$((APP_SIZE + 20))

echo "Creating temporary DMG (${DMG_SIZE}MB)..."

# 创建临时 DMG
hdiutil create -srcfolder "${DMG_TEMP}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "build/${DMG_NAME}-temp.dmg"

# 挂载 DMG
echo "Mounting DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "build/${DMG_NAME}-temp.dmg" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

echo "Mounted at: ${MOUNT_DIR}"

# 等待挂载完成
sleep 2

# 使用 AppleScript 设置 DMG 窗口样式
echo "Configuring DMG window..."

# 设置窗口大小和图标位置
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        
        -- 设置背景
        if exists file ".background:background.png" then
            set background picture of viewOptions to file ".background:background.png"
        end if
        
        -- 设置图标位置
        set position of item "${APP_NAME}.app" of container window to {140, 200}
        set position of item "Applications" of container window to {380, 200}
        
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# 同步并卸载
sync
hdiutil detach "${MOUNT_DIR}"

# 转换为压缩格式
echo "Converting to compressed DMG..."
hdiutil convert "build/${DMG_NAME}-temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"

# 清理临时文件
rm -f "build/${DMG_NAME}-temp.dmg"
rm -rf "${DMG_TEMP}"

echo "DMG created: ${DMG_PATH}"



