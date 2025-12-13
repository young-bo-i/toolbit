import SwiftUI

/// 更新提示悬浮组件 - 只在下载完成后显示
struct UpdateBanner: View {
    @ObservedObject var updateManager = UpdateManager.shared
    @State private var isHovered = false
    @State private var isCloseHovered = false
    
    var body: some View {
        if updateManager.showUpdateBanner {
            bannerContent
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: updateManager.showUpdateBanner)
        }
    }
    
    @ViewBuilder
    private var bannerContent: some View {
        switch updateManager.status {
        case .readyToInstall:
            HStack(spacing: 8) {
                // 主按钮区域
                Button(action: installAndRestart) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                        
                        Text("更新已就绪，点击安装并重启")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                
                // 分隔线
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 1, height: 12)
                
                // 关闭按钮
                Button(action: closeBanner) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isCloseHovered ? .white : .white.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(isCloseHovered ? .white.opacity(0.2) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCloseHovered = hovering
                    }
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                isHovered ? Color.green.opacity(0.95) : Color.green.opacity(0.85),
                                isHovered ? Color.green.opacity(0.85) : Color.green.opacity(0.75)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(isHovered ? 0.3 : 0.2), radius: isHovered ? 10 : 6, x: 0, y: isHovered ? 4 : 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
        case .installing, .installSuccess:
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
                    .tint(.white)
                
                Text("正在安装，即将重启...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.85), Color.orange.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
            )
            
        default:
            EmptyView()
        }
    }
    
    private func closeBanner() {
        withAnimation(.easeInOut(duration: 0.2)) {
            updateManager.dismissBanner()
        }
    }
    
    private func installAndRestart() {
        if case .readyToInstall(let localPath) = updateManager.status {
            updateManager.installUpdate(from: localPath)
        }
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        VStack {
            UpdateBanner()
                .padding(.top, 10)
            Spacer()
        }
    }
}

