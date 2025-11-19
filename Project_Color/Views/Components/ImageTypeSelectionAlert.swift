//
//  ImageTypeSelectionAlert.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  图像类型选择弹窗（我的作品 vs 其他图像）
//

import SwiftUI

/// 图像类型
enum ImageType {
    case personalWork  // 我的作品
    case otherImage    // 其他图像
}

/// 图像类型选择结果
enum ImageTypeSelectionResult {
    case selected(ImageType)
    case cancelled
}

/// 图像类型选择弹窗的 ViewModifier
struct ImageTypeSelectionAlert: ViewModifier {
    @Binding var isPresented: Bool
    let onSelection: (ImageTypeSelectionResult) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("选择图像类型", isPresented: $isPresented) {
                // 我的作品按钮
                Button("🎨 我的作品\n数据会存入个人信息") {
                    onSelection(.selected(.personalWork))
                }
                
                // 其他图像按钮
                Button("📷 其他图像\n数据不会记录") {
                    onSelection(.selected(.otherImage))
                }
                
                // 取消按钮
                Button("取消", role: .cancel) {
                    onSelection(.cancelled)
                }
            } message: {
                Text("请选择图像类型")
            }
    }
}

extension View {
    /// 显示图像类型选择弹窗
    func imageTypeSelectionAlert(
        isPresented: Binding<Bool>,
        onSelection: @escaping (ImageTypeSelectionResult) -> Void
    ) -> some View {
        modifier(ImageTypeSelectionAlert(isPresented: isPresented, onSelection: onSelection))
    }
}

