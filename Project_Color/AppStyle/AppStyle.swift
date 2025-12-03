//
//  AppStyle.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/12/4.
//

import SwiftUI

struct AppStyle {
    /// Tab 页标题字号
    static let tabTitleFontSize: CGFloat = 28
    
    /// Tab 页标题字体粗细
    static let tabTitleFontWeight: Font.Weight = .bold
    
    /// Tab 页标题顶部 padding
    static let tabTitleTopPadding: CGFloat = 8
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // 示例标题样式
        Text("相册")
            .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, AppStyle.tabTitleTopPadding)
        
        Text("我的")
            .font(.system(size: AppStyle.tabTitleFontSize, weight: AppStyle.tabTitleFontWeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, AppStyle.tabTitleTopPadding)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
