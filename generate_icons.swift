#!/usr/bin/env swift

import Cocoa
import Foundation

// 图标尺寸配置 - 实际像素尺寸
let iconSizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024)
]

// 输出目录
let outputDir = "Toolbit/Assets.xcassets/AppIcon.appiconset"

// 保存为指定尺寸的 PNG - 使用与 AppLogoView 一致的颜色
func generateIcon(to path: String, targetSize: Int) {
    let cgSize = CGFloat(targetSize)
    
    // 创建精确尺寸的位图
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetSize,
        pixelsHigh: targetSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        print("✗ Failed to create bitmap for: \(path)")
        return
    }
    
    bitmapRep.size = NSSize(width: cgSize, height: cgSize)
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    
    // 绘制渐变背景 - 与 AppLogoView 一致的颜色
    if let context = NSGraphicsContext.current?.cgContext {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // 深蓝 -> 紫色 -> 玫红 (与 AppLogoView 一致)
        let colors = [
            CGColor(red: 0.15, green: 0.25, blue: 0.5, alpha: 1.0),   // 深蓝
            CGColor(red: 0.45, green: 0.2, blue: 0.5, alpha: 1.0),    // 紫色
            CGColor(red: 0.7, green: 0.25, blue: 0.4, alpha: 1.0)     // 玫红
        ] as CFArray
        
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            // 从左上到右下的渐变 (topLeading -> bottomTrailing)
            let startPoint = CGPoint(x: 0, y: cgSize)
            let endPoint = CGPoint(x: cgSize, y: 0)
            context.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
    }
    
    // 绘制白色图标 (使用 SF Symbols)
    let iconFontSize = cgSize * 0.45
    if let symbolImage = NSImage(systemSymbolName: "wrench.and.screwdriver", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: iconFontSize, weight: .semibold)
        var symbolWithConfig = symbolImage.withSymbolConfiguration(config) ?? symbolImage
        
        // 将图标着色为白色
        let tintedImage = NSImage(size: symbolWithConfig.size)
        tintedImage.lockFocus()
        NSColor.white.set()
        let imageRect = NSRect(origin: .zero, size: symbolWithConfig.size)
        symbolWithConfig.draw(in: imageRect)
        imageRect.fill(using: .sourceAtop)
        tintedImage.unlockFocus()
        
        // 计算居中位置
        let symbolSize = tintedImage.size
        let x = (cgSize - symbolSize.width) / 2
        let y = (cgSize - symbolSize.height) / 2
        let destRect = NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)
        
        tintedImage.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    NSGraphicsContext.restoreGraphicsState()
    
    // 保存 PNG
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("✗ Failed to create PNG data for: \(path)")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("✓ Generated: \(path) (\(targetSize)x\(targetSize))")
    } catch {
        print("✗ Failed to save: \(path) - \(error)")
    }
}

// 主程序
print("🎨 Generating App Icons...")
print("Output directory: \(outputDir)")
print("")

for (name, size) in iconSizes {
    let path = "\(outputDir)/\(name).png"
    generateIcon(to: path, targetSize: size)
}

print("")
print("✅ Done! Icons generated to \(outputDir)")
