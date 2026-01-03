//
//  KitView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/11.
//

import SwiftUI

struct KitView: View {
    // MARK: - 布局常量
    private enum Layout {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 14
        static let rowHorizontalPadding: CGFloat = 16
    }
    
    // MARK: - State
    @State private var developmentMode: BatchProcessSettings.DevelopmentMode = BatchProcessSettings.developmentMode
    @State private var developmentShape: BatchProcessSettings.DevelopmentShape = BatchProcessSettings.developmentShape
    @Environment(\.openURL) private var openURL
    
    @State private var showUnlockSheet = false
    // iCloud 同步状态
    @State private var navigateToCloudSettings = false
    
    // 分享状态
    @State private var showShareSheet = false
    
    // Pro 功能限制提示
    @State private var showProFeatureAlert = false
    @State private var proFeatureAlertTitle = ""
    
    // 订阅管理器
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        // iOS 16+ 兼容：使用条件编译选择最佳导航方案
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    contentView
                        .navigationDestination(isPresented: $navigateToCloudSettings) {
                            CloudSyncSettingsView()
                        }
                }
            } else {
                NavigationView {
                    contentView
                }
                .navigationViewStyle(.stack)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .fullScreenCover(isPresented: $showUnlockSheet) {
            UnlockAISheetView {
                showUnlockSheet = false
            }
        }
        .alert(proFeatureAlertTitle, isPresented: $showProFeatureAlert) {
            Button(L10n.Common.cancel.localized, role: .cancel) { }
            Button(L10n.Kit.viewDetails.localized) {
                showUnlockSheet = true
            }
        }
        .onAppear {
            developmentMode = BatchProcessSettings.developmentMode
            developmentShape = BatchProcessSettings.developmentShape
            print("🔍 [KitView] 当前订阅状态: isProUser = \(subscriptionManager.isProUser)")
        }
    }
    
    // MARK: - 主内容视图
    private var contentView: some View {
            VStack(spacing: 0) {
                // 标题
                Text(L10n.Mine.title.localized)
                    .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, AppStyle.tabTitleTopPadding)
                    .padding(.bottom, 8)
                
                // 内容区域
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    // 使用限制显示
                    AnalysisLimitView()
                        .padding(.top, 16)
                    
                    // 第一个卡片：云相册 + 照片暗房
                    featuresCard
                    
                    // 第三个卡片：显影模式 + 显影形状（单独）
                    developmentCard
                    
                    // 第四个卡片：色彩实验室（单独）
                    labCard
                    
                    // 第五个卡片：更多选项（反馈、鼓励、分享、关于）
                    moreOptionsCard
                }
                .padding(.horizontal, Layout.horizontalPadding)
                }
            }
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
    
    
    // MARK: - 功能入口卡片
    private var featuresCard: some View {
        VStack(spacing: 0) {
            // 云相册（隐藏但保留代码）
            if false {
                ZStack {
                    // iOS 16 以下使用 NavigationLink
                    if #available(iOS 16.0, *) {
                        // iOS 16+ 使用 programmatic navigation
                        EmptyView()
                    } else {
                        NavigationLink(destination: CloudSyncSettingsView(), isActive: $navigateToCloudSettings) {
                            EmptyView()
                        }
                        .hidden()
                    }
                    
                    Button {
                        handleCloudAlbumTap()
                    } label: {
                        KitMenuRow(
                            icon: "cloud",
                            title: L10n.Mine.cloudAlbum.localized
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 照片暗房
            NavigationLink {
                BatchProcessView()
            } label: {
                KitMenuRow(
                    icon: "slider.horizontal.below.square.filled.and.square",
                    title: L10n.Mine.photoDarkroom.localized
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
            
    // MARK: - 显影设置卡片（显影模式 + 显影形状）
    private var developmentCard: some View {
        VStack(spacing: 0) {
            // 显影模式
            HStack(spacing: 12) {
                Image("emerge_mode")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.primary)
                    .frame(width: 20, height: 20)
                    .frame(width: 28)
                
                Text(L10n.Mine.developmentMode.localized)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    ForEach(BatchProcessSettings.DevelopmentMode.allCases, id: \.self) { mode in
                        let isProMode = mode == .tone || mode == .shadow
                        let isLocked = isProMode && !subscriptionManager.isProUser
                        
                        Button {
                            // ✅ 检查 Pro 权限（融合模式免费，色调和影调需要 Pro）
                            if isLocked {
                                proFeatureAlertTitle = L10n.Kit.unlockMoreModes.localized
                                showProFeatureAlert = true
                                return
                            }
                            
                            withAnimation(.easeInOut(duration: 0.3)) {
                                developmentMode = mode
                                BatchProcessSettings.developmentMode = mode
                                // ✅ 如果切换到影调模式，强制更新显影形状为 circle
                                if mode == .shadow {
                                    developmentShape = .circle
                                } else {
                                    // 切换回其他模式时，读取保存的形状
                                    developmentShape = BatchProcessSettings.developmentShape
                                }
                            }
                        } label: {
                            HStack {
                                // 锁定图标（仅在未解锁时显示）
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Text(mode.displayName)
                                Spacer()
                                // 选中标记
                                if mode == developmentMode {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(developmentMode.displayName)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minWidth: 110, alignment: .trailing)
                        
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, Layout.rowHorizontalPadding)
            .padding(.vertical, Layout.rowVerticalPadding)
            .contentShape(Rectangle())
            
            // 显影形状（影调模式时隐藏）
            if developmentMode != .shadow {
                HStack(spacing: 12) {
                Image("shape")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.primary)
                    .frame(width: 20, height: 20)
                    .frame(width: 28)
                
                Text(L10n.DevelopmentShape.title.localized)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 显影形状选择器
                // 免费用户：点击显示升级提示
                // Pro 用户：显示下拉菜单
                if subscriptionManager.isProUser {
                    // Pro 用户：显示完整的下拉菜单
                    Menu {
                        ForEach(BatchProcessSettings.availableShapes(), id: \.self) { shape in
                            Button {
                                developmentShape = shape
                                BatchProcessSettings.developmentShape = shape
                            } label: {
                                Label {
                                    HStack {
                                        Spacer()
                                        if shape == developmentShape {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                    }
                                } icon: {
                                    if shape == .circle {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 20))
                                    } else if shape == .flower {
                                        Image("flower")
                                            .resizable()
                                            .renderingMode(.template)
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image("flower_with_stem")
                                            .resizable()
                                            .renderingMode(.template)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            // 显示当前选中的图标
                            if developmentShape == .circle {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            } else if developmentShape == .flower {
                                Image("flower")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image("flower_with_stem")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            }
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // 免费用户：点击显示升级提示
                    Button {
                        proFeatureAlertTitle = L10n.Kit.unlockMoreShapes.localized
                        showProFeatureAlert = true
                    } label: {
                        HStack(spacing: 4) {
                            // 显示当前选中的图标（通常是 circle）
                            if developmentShape == .circle {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            } else if developmentShape == .flower {
                                Image("flower")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            } else {
                                Image("flower_with_stem")
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(.primary)
                                    .frame(width: 20, height: 20)
                            }
                            
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                }
                .padding(.horizontal, Layout.rowHorizontalPadding)
                .padding(.vertical, Layout.rowVerticalPadding)
                .contentShape(Rectangle())
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - 色彩实验室卡片（单独）
    private var labCard: some View {
        NavigationLink {
            LabView()
        } label: {
            KitMenuRow(
                icon: "paintpalette",
                title: L10n.Mine.colorLab.localized
            )
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - 分享内容
    private var shareItems: [Any] {
        let currentLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        
        if currentLanguage.hasPrefix("zh") {
            // 中文分享内容
            let shareText = """
            推荐一款色彩分析 App - Feelm
            
            用摄影的方式，看见你的色彩。
            
            🎨 智能色彩分析
            📸 照片色彩提取
            🌈 色彩空间可视化
            
            （App 正在开发中，敬请期待）
            """
            return [shareText]
        } else {
            // 英文分享内容
            let shareText = """
            Check out Feelm - A Color Analysis App
            
            See your colors through the lens of photography.
            
            🎨 Smart Color Analysis
            📸 Photo Color Extraction
            🌈 Color Space Visualization
            
            (App is under development, stay tuned)
            """
            return [shareText]
        }
    }
    
    // MARK: - 更多选项卡片
    private var moreOptionsCard: some View {
        VStack(spacing: 0) {
            // 反馈与联系
            Button {
                // 打开邮件客户端
                if let url = URL(string: "mailto:deerhino@hotmail.com") {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #else
                    openURL(url)
                    #endif
                }
            } label: {
                KitMenuRow(
                    icon: "envelope",
                    title: L10n.Mine.feedback.localized
                )
            }
            .buttonStyle(.plain)
            
            // 鼓励一下（已隐藏）
            // Button {
            //     // TODO: 添加鼓励一下功能
            // } label: {
            //     KitMenuRow(
            //         icon: "hands.clap",
            //         title: L10n.Mine.encourage.localized,
            //         secondaryText: L10n.Mine.encourageSubtitle.localized
            //     )
            // }
            // .buttonStyle(.plain)
            
            // 分享给朋友
            Button {
                showShareSheet = true
            } label: {
                KitMenuRow(
                    icon: "paperplane",
                    title: L10n.Mine.share.localized
                )
            }
            .buttonStyle(.plain)
            
            // 关于 Feelm
            NavigationLink {
                AboutView()
            } label: {
                KitMenuRow(
                    icon: "info.circle",
                    title: L10n.Mine.aboutFeelm.localized
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - Methods
    
    private func handleCloudAlbumTap() {
        // 直接进入设置页面
        navigateToCloudSettings = true
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)
#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
#endif

#Preview {
    KitView()
}
