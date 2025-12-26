//
//  KitMenuRow.swift
//  Project_Color
//
//  通用菜单行组件（用于 KitView 和其他设置页面）
//

import SwiftUI

/// 菜单行视图 - 用于设置页面的统一样式菜单项
struct KitMenuRow: View {
    let icon: String
    let title: String
    let secondaryText: String?
    
    init(icon: String, title: String, secondaryText: String? = nil) {
        self.icon = icon
        self.title = title
        self.secondaryText = secondaryText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            if let secondaryText = secondaryText {
                Text(secondaryText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, 4)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 0) {
        KitMenuRow(
            icon: "cloud",
            title: "云相册"
        )
        
        Divider()
        
        KitMenuRow(
            icon: "hands.clap",
            title: "鼓励一下",
            secondaryText: "如果感到快乐你就拍拍手"
        )
    }
    .background(Color(.systemBackground))
    .cornerRadius(20)
    .padding()
}

