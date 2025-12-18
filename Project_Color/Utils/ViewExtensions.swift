//
//  ViewExtensions.swift
//  Project_Color
//
//  Created for iOS 16 compatibility
//

import SwiftUI

// MARK: - View 扩展：支持条件编译
extension View {
    /// 通用的条件应用修饰符
    /// 用于在条件编译中灵活应用不同的修饰符
    @ViewBuilder
    func apply<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}

