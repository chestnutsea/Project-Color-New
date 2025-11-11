//
//  KitView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/11.
//

import SwiftUI

struct KitView: View {
    // MARK: - 布局常量
    private let titleFont: Font = .system(size: 18, weight: .semibold)
    private let titleColor: Color = .primary
    private let descriptionFont: Font = .system(size: 14, weight: .regular)
    private let descriptionColor: Color = .secondary
    private let dividerColor: Color = Color(.separator)
    private let menuItemPadding: CGFloat = 16
    private let menuItemVerticalPadding: CGFloat = 16
    
    // MARK: - 菜单数据
    private let menuItems: [(title: String, description: String)] = [
        ("集色", "颜色收藏与历史分析记录"),
        ("查色", "为颜色找到最贴近的名字"),
        ("寻色", "寻找含特定颜色的照片"),
        ("探色", "根据关键词探索颜色"),
        ("算色", "在不同颜色空间中进行换算"),
        ("筑色", "生成两种颜色间的过渡色"),
        ("采色", "为单张照片采集代表色"),
        ("遇色", "偶遇一种颜色")
    ]
    
    @State private var showLookUpColor = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(menuItems.enumerated()), id: \.offset) { index, item in
                        Group {
                            if item.title == "寻色" {
                                NavigationLink {
                                    SearchColorView()
                                } label: {
                                    menuRow(for: item)
                                }
                                .buttonStyle(.plain)
                            } else if item.title == "算色" {
                                NavigationLink {
                                    CalculateColorView()
                                } label: {
                                    menuRow(for: item)
                                }
                                .buttonStyle(.plain)
                            } else {
                                menuRow(for: item) {
                                    if item.title == "查色" {
                                        showLookUpColor = true
                                    }
                                }
                            }
                        }
                        
                        if index < menuItems.count - 1 {
                            Divider()
                                .background(dividerColor)
                                .padding(.leading, menuItemPadding)
                        }
                    }
                }
            }
            .navigationTitle("调色盘")
            .background(Color(.systemGroupedBackground))
            .fullScreenCover(isPresented: $showLookUpColor) {
                LookUpColorView()
            }
        }
    }
    
    // MARK: - Menu Row
    @ViewBuilder
    private func menuRow(for item: (title: String, description: String), onTap: (() -> Void)? = nil) -> some View {
        MenuItemRow(
            title: item.title,
            description: item.description,
            titleFont: titleFont,
            titleColor: titleColor,
            descriptionFont: descriptionFont,
            descriptionColor: descriptionColor,
            onTap: onTap
        )
        .padding(.horizontal, menuItemPadding)
        .padding(.vertical, menuItemVerticalPadding)
    }
}

// MARK: - 菜单项行视图
struct MenuItemRow: View {
    let title: String
    let description: String
    let titleFont: Font
    let titleColor: Color
    let descriptionFont: Font
    let descriptionColor: Color
    let onTap: (() -> Void)?
    
    init(
        title: String,
        description: String,
        titleFont: Font,
        titleColor: Color,
        descriptionFont: Font,
        descriptionColor: Color,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.titleFont = titleFont
        self.titleColor = titleColor
        self.descriptionFont = descriptionFont
        self.descriptionColor = descriptionColor
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)
            
            Text(description)
                .font(descriptionFont)
                .foregroundColor(descriptionColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .ifLet(onTap) { view, action in
            view.onTapGesture { action() }
        }
    }
}

#Preview {
    KitView()
}

private extension View {
    @ViewBuilder
    func ifLet<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
