//
//  LabView.swift
//  Project_Color
//
//  色彩实验室页面 - 包含查色、算色功能
//

import SwiftUI

struct LabView: View {
    // MARK: - 布局常量
    private enum Layout {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let verticalSpacing: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 14
        static let rowHorizontalPadding: CGFloat = 16
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.verticalSpacing) {
                // 色彩实验室功能卡片
                VStack(spacing: 0) {
                    // 查色
                    NavigationLink {
                        LookUpColorView()
                            .hideTabBar()
                    } label: {
                        LabMenuRow(
                            icon: "eyedropper",
                            title: L10n.Lab.searchColor.localized,
                            subtitle: L10n.Lab.searchColorSubtitle.localized
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 算色
                    NavigationLink {
                        CalculateColorView()
                            .hideTabBar()
                    } label: {
                        LabMenuRow(
                            icon: "function",
                            title: L10n.Lab.calculateColor.localized,
                            subtitle: L10n.Lab.calculateColorSubtitle.localized
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.systemBackground))
                .cornerRadius(Layout.cornerRadius)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.verticalSpacing)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Lab.title.localized)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
    }
}

// MARK: - 色彩实验室菜单行
private struct LabMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
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
    NavigationView {
        LabView()
    }
}

