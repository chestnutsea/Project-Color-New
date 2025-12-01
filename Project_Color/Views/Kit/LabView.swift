//
//  LabView.swift
//  Project_Color
//
//  实验暗房页面 - 包含查色、算色功能
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
    
    // MARK: - State
    @State private var showLookUpColor = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.verticalSpacing) {
                // 实验功能卡片
                VStack(spacing: 0) {
                    // 查色
                    Button {
                        showLookUpColor = true
                    } label: {
                        LabMenuRow(
                            icon: "eyedropper",
                            title: "查色",
                            subtitle: "为颜色找到最贴近的名字"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // 算色
                    NavigationLink {
                        CalculateColorView()
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
        .navigationTitle("实验暗房")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showLookUpColor) {
            NavigationView {
                LookUpColorWrapperView()
            }
        }
    }
}

// MARK: - 实验暗房菜单行
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

// MARK: - LookUpColor 包装视图（添加导航栏）
struct LookUpColorWrapperView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        LookUpColorView()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                            Text("返回")
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
    }
}

#Preview {
    NavigationView {
        LabView()
    }
}

