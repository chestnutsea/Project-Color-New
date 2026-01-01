//
//  AboutView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/12/13.
//

import SwiftUI

struct AboutView: View {
    // MARK: - 布局常量
    private enum Layout {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let cardSpacing: CGFloat = 16
    }
    
    // MARK: - Environment
    @Environment(\.openURL) private var openURL
    
    // MARK: - 多语言链接
    /// 根据当前语言返回对应的链接
    private var descriptionURL: String {
        if LocalizationManager.shared.isChineseLanguage {
            return "https://www.yuque.com/deerhino/oi51m5/vhw0xwftgvvwudve"  // 中文链接
        } else {
            return "https://www.yuque.com/deerhino/oi51m5/qds3g1pao0tskyzh"  // 英文链接
        }
    }
    
    private var iterationLogURL: String {
        if LocalizationManager.shared.isChineseLanguage {
            return "https://www.yuque.com/deerhino/oi51m5/px1sf23bi5kdprdw"  // 中文链接
        } else {
            return "https://www.yuque.com/deerhino/oi51m5/vcu1zs2w4mk3iza5"  // 英文链接
        }
    }
    
    private var privacyPolicyURL: String {
        if LocalizationManager.shared.isChineseLanguage {
            return "https://www.yuque.com/deerhino/oi51m5/rzqhif0xn55r788n"  // 中文链接
        } else {
            return "https://www.yuque.com/deerhino/oi51m5/gicclr4m62wsrb9r"  // 英文链接
        }
    }
    
    private var termsOfUseURL: String {
        if LocalizationManager.shared.isChineseLanguage {
            return "https://www.yuque.com/deerhino/oi51m5/iv130myyrgko7fwk"  // 中文链接
        } else {
            return "https://www.yuque.com/deerhino/oi51m5/iwrgdabsx5geh6yr"  // 英文链接
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.cardSpacing) {
                // 说明卡片：包含三个选项
                infoCard
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Mine.aboutFeelm.localized)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
    }
    
    // MARK: - 说明卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 许可与法律信息
            Button {
                if let url = URL(string: descriptionURL) {
                    openURL(url)
                }
            } label: {
                KitMenuRow(
                    icon: "doc.text",
                    title: L10n.About.legalInfo.localized
                )
            }
            .buttonStyle(.plain)
            
            // 迭代记录
            Button {
                if let url = URL(string: iterationLogURL) {
                    openURL(url)
                }
            } label: {
                KitMenuRow(
                    icon: "shoeprints.fill",
                    title: L10n.About.iterationLog.localized
                )
            }
            .buttonStyle(.plain)
            
            // 使用条款
            Button {
                if let url = URL(string: termsOfUseURL) {
                    openURL(url)
                }
            } label: {
                KitMenuRow(
                    icon: "doc.plaintext",
                    title: L10n.About.termsOfUse.localized
                )
            }
            .buttonStyle(.plain)
            
            // 隐私与数据说明
            Button {
                if let url = URL(string: privacyPolicyURL) {
                    openURL(url)
                }
            } label: {
                KitMenuRow(
                    icon: "lock.shield",
                    title: L10n.About.privacyPolicy.localized
                )
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
    }
}

#Preview {
    if #available(iOS 16.0, *) {
    NavigationStack {
        AboutView()
        }
    } else {
        NavigationView {
            AboutView()
        }
    }
}

