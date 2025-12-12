import SwiftUI

/// 应用 Logo 视图 - 现代渐变 + 扳手螺丝刀图案
struct AppLogoView: View {
    let size: CGFloat
    var cornerRadius: CGFloat? = nil
    
    private var computedCornerRadius: CGFloat {
        cornerRadius ?? (size * 0.22)
    }
    
    private var iconSize: CGFloat {
        size * 0.45
    }
    
    var body: some View {
        ZStack {
            // 渐变背景 - 深蓝到紫红的渐变
            RoundedRectangle(cornerRadius: computedCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.25, blue: 0.5),   // 深蓝
                            Color(red: 0.45, green: 0.2, blue: 0.5),    // 紫色
                            Color(red: 0.7, green: 0.25, blue: 0.4)     // 玫红
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 图标
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.5, green: 0.2, blue: 0.4).opacity(0.4), radius: size * 0.1, y: size * 0.05)
    }
}

/// 用于导出 App Icon 的视图（可以截图使用）
struct AppIconExportView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // 背景色（用于预览）
            Color(red: 0.15, green: 0.13, blue: 0.2)
            
            AppLogoView(size: size, cornerRadius: 0)
        }
        .frame(width: size, height: size)
    }
}

#Preview("Logo 64px") {
    AppLogoView(size: 64)
        .padding()
}

#Preview("Logo 128px") {
    AppLogoView(size: 128)
        .padding()
}

#Preview("Logo 256px") {
    AppLogoView(size: 256)
        .padding()
}

#Preview("Export 512px") {
    AppIconExportView(size: 512)
}

#Preview("Export 1024px") {
    AppIconExportView(size: 1024)
}

