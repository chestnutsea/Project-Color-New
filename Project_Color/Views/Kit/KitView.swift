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
    
    // iCloud 同步状态
    @State private var navigateToCloudSettings = false
    
    // 分享状态
    @State private var showShareSheet = false
    
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
        .onAppear {
            developmentMode = BatchProcessSettings.developmentMode
            developmentShape = BatchProcessSettings.developmentShape
        }
    }
    
    // MARK: - 主内容视图
    private var contentView: some View {
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    // 自定义标题
                    Text(L10n.Mine.title.localized)
                        .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, AppStyle.tabTitleTopPadding)
                        .padding(.bottom, 8)
                    
                    // 第一个卡片：解锁 AI 视角
                    aiUnlockCard
                    
                    // 第二个卡片：云相册 + 照片暗房
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
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        )
        .navigationBarHidden(true)
    }
    
    // MARK: - AI 解锁卡片
    private var aiUnlockCard: some View {
        Button {
            // TODO: 实现 AI 解锁功能
        } label: {
            KitMenuRow(
                icon: "atom",
                title: L10n.Mine.unlockAI.localized
            )
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - 功能入口卡片
    private var featuresCard: some View {
        VStack(spacing: 0) {
            // 云相册
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
                        Button {
                            developmentMode = mode
                            BatchProcessSettings.developmentMode = mode
                        } label: {
                            if mode == developmentMode {
                                Label(mode.displayName, systemImage: "checkmark")
                            } else {
                                Text(mode.displayName)
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
            
            // 显影形状
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
                
                // 显影形状下拉菜单
                Menu {
                    ForEach(BatchProcessSettings.DevelopmentShape.allCases, id: \.self) { shape in
                        Button {
                            developmentShape = shape
                            BatchProcessSettings.developmentShape = shape
                        } label: {
                            HStack {
                                if shape == .circle {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 22))
                                        .frame(width: 20, height: 20)
                                } else if shape == .flower {
                                    Image("flower")
                                        .resizable()
                                        .renderingMode(.template)
                                        .frame(width: 18, height: 18)
                                } else {
                                    Image("flower_with_stem")
                                        .resizable()
                                        .renderingMode(.template)
                                        .frame(width: 18, height: 18)
                                }
                                if shape == developmentShape {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        // 只显示当前选中的图标
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
            .padding(.horizontal, Layout.rowHorizontalPadding)
            .padding(.vertical, Layout.rowVerticalPadding)
            .contentShape(Rectangle())
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
                // TODO: 实现反馈功能
            } label: {
                KitMenuRow(
                    icon: "envelope",
                    title: L10n.Mine.feedback.localized
                )
            }
            .buttonStyle(.plain)
            
            // 鼓励一下
            Button {
                // TODO: 添加鼓励一下功能
            } label: {
                KitMenuRow(
                    icon: "hands.clap",
                    title: L10n.Mine.encourage.localized,
                    secondaryText: L10n.Mine.encourageSubtitle.localized
                )
            }
            .buttonStyle(.plain)
            
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
