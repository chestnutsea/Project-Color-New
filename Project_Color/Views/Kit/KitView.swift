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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    // 自定义标题
                    Text("我的")
                        .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, AppStyle.tabTitleTopPadding)
                        .padding(.bottom, 8)
                    
                    // 第一个卡片：解锁 AI 视角
                    aiUnlockCard
                    
                    // 第二个卡片：云相册 + 照片暗房 + 显影模式
                    featuresCard
                    
                    // 第三个卡片：色彩实验室（单独）
                    labCard
                    
                    // 第四个卡片：迭代记录和隐私说明
                    infoCard
                    
                    // 第五个卡片：更多选项（反馈、鼓励、分享）
                    moreOptionsCard
                }
                .padding(.horizontal, Layout.horizontalPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                // 每次进入页面时从设置读取最新值
                developmentMode = BatchProcessSettings.developmentMode
            }
        }
    }
    
    // MARK: - AI 解锁卡片
    private var aiUnlockCard: some View {
        Button {
            // TODO: 添加解锁 AI 视角功能
        } label: {
            KitMenuRow(
                icon: "atom",
                title: "解锁 AI 视角"
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
            Button {
                // TODO: 添加云相册功能
            } label: {
                KitMenuRow(
                    icon: "cloud",
                    title: "云相册"
                )
            }
            .buttonStyle(.plain)
            
            // 照片暗房
            NavigationLink {
                BatchProcessView()
            } label: {
                KitMenuRow(
                    icon: "slider.horizontal.below.square.filled.and.square",
                    title: "照片暗房"
                )
            }
            .buttonStyle(.plain)
            
            // 显影模式
            HStack(spacing: 12) {
                Image(systemName: "camera.filters")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 28)
                
                Text("显影模式")
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
                                Label(mode.rawValue, systemImage: "checkmark")
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(developmentMode.rawValue)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.secondary)
                        
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
                title: "色彩实验室"
            )
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - 信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 迭代记录
            Button {
                // TODO: 添加迭代记录功能
            } label: {
                KitMenuRow(
                    icon: "shoeprints.fill",
                    title: "迭代记录"
                )
            }
            .buttonStyle(.plain)
            
            // 隐私与数据说明
            Button {
                // TODO: 添加隐私与数据说明功能
            } label: {
                KitMenuRow(
                    icon: "lock.shield",
                    title: "隐私与数据说明"
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
    
    // MARK: - 更多选项卡片
    private var moreOptionsCard: some View {
        VStack(spacing: 0) {
            // 反馈与联系
            Button {
                // TODO: 添加反馈与联系功能
            } label: {
                KitMenuRow(
                    icon: "envelope",
                    title: "反馈与联系"
                )
            }
            .buttonStyle(.plain)
            
            // 鼓励一下
            Button {
                // TODO: 添加鼓励一下功能
            } label: {
                KitMenuRow(
                    icon: "hand.thumbsup",
                    title: "鼓励一下"
                )
            }
            .buttonStyle(.plain)
            
            // 分享给朋友
            Button {
                // TODO: 添加分享给朋友功能
            } label: {
                KitMenuRow(
                    icon: "paperplane",
                    title: "分享给朋友"
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
}

// MARK: - 菜单行视图
private struct KitMenuRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    KitView()
}
