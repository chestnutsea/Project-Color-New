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
                            title: "查色",
                            subtitle: "在人们共建的色彩词典里，找到最接近的那一个"
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
                            title: "算色",
                            subtitle: "在不同颜色空间中进行换算"
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
        .navigationTitle("色彩实验室")
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

