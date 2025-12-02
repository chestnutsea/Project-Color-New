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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Layout.cardSpacing) {
                    // 第一个卡片：解锁 AI 视角
                    aiUnlockCard
                    
                    // 第二个卡片：功能入口
                    featuresCard
                    
                    // 第三个卡片：迭代记录和隐私说明
                    infoCard
                    
                    // 第四个卡片：更多选项（反馈、鼓励、分享）
                    moreOptionsCard
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Layout.cardSpacing)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("我的")
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
            
            // 暗房参数
            NavigationLink {
                BatchProcessView()
            } label: {
                KitMenuRow(
                    icon: "slider.horizontal.3",
                    title: "暗房参数"
                )
            }
            .buttonStyle(.plain)
            
            // 色彩实验室
            NavigationLink {
                LabView()
            } label: {
                KitMenuRow(
                    icon: "paintpalette",
                    title: "色彩实验室"
                )
            }
            .buttonStyle(.plain)
        }
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
