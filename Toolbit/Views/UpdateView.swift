import SwiftUI
import AppKit

/// 关于视图 - 只显示应用信息
struct AboutView: View {
    @ObservedObject var updateManager = UpdateManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // 应用图标
            AppLogoView(size: 80)
            
            // 应用名称
            Text("Toolbit")
                .font(.title)
                .fontWeight(.bold)
            
            // 版本信息
            Text("版本 \(updateManager.currentVersion) (Build \(updateManager.currentBuild))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // 描述
            Text("开发者工具集")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Divider()
                .padding(.horizontal, 40)
            
            // 链接
            HStack(spacing: 20) {
                Button("访问 GitHub") {
                    updateManager.openHomePage()
                }
                .buttonStyle(.link)
            }
            
            Spacer()
            
            // 版权信息
            Text("© 2024 Toolbit. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(width: 300, height: 320)
    }
}

#Preview {
    AboutView()
}
