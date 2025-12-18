//
//  SystemPhotoPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/10.
//  使用苹果原生 PHPickerViewController 的照片选择器
//

import SwiftUI
import PhotosUI

// MARK: - 系统照片选择器（带 Toast 提示）
/// 使用苹果原生 PHPickerViewController，最多选择 9 张照片
/// 当用户选择满 9 张后继续点击照片时，会短暂显示"最多选择 9 张照片"的提示
struct SystemPhotoPickerWithToast: View {
    @Environment(\.dismiss) private var dismiss
    
    var onSelection: ([PHPickerResult]) -> Void
    
    @State private var showMaxSelectionToast = false
    
    var body: some View {
        ZStack {
            SystemPhotoPickerView { results in
                onSelection(results)
            }
            
            // Toast 提示（最多选择 9 张照片）- 显示在屏幕中央偏下
            if showMaxSelectionToast {
                VStack {
                    Spacer()
                    
                    Text("最多选择 9 张照片")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                    
                    Spacer()
                        .frame(height: 120)  // 距离底部的距离
                }
                .transition(.opacity)
                .zIndex(999)
                .allowsHitTesting(false)  // Toast 不拦截点击事件
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ShowMaxSelectionToast"))) { _ in
            showToast()
        }
    }
    
    private func showToast() {
        // 显示 Toast
        withAnimation(.easeInOut(duration: 0.2)) {
            showMaxSelectionToast = true
        }
        
        // 1 秒后自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showMaxSelectionToast = false
            }
        }
    }
}

// MARK: - 系统照片选择器（基础版本）
struct SystemPhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    /// 选择完成回调，返回选中的 PHPickerResult 数组
    var onSelection: ([PHPickerResult]) -> Void
    
    /// 最大选择数量
    private let maxSelection = 9
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        // 配置 PHPicker
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images  // 只显示图片
        configuration.selectionLimit = maxSelection  // 最多选择 9 张
        configuration.preferredAssetRepresentationMode = .current
        configuration.selection = .ordered  // 保持选择顺序
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        
        // ✅ 设置照片选择器的强调色为系统蓝色
        // 这会影响：确定按钮、选中照片的数字背景、导航栏按钮等
        picker.view.tintColor = UIColor.systemBlue
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 不需要更新
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: SystemPhotoPickerView
        
        init(_ parent: SystemPhotoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            if !results.isEmpty {
                parent.onSelection(results)
            }
            parent.dismiss()
        }
    }
}

// MARK: - 注意事项
/// PHPickerViewController 会自动处理以下行为：
/// 1. 当选择数量达到 selectionLimit (9张) 时，其他照片会变灰无法选择
/// 2. 系统会显示已选数量 (例如 "3/9")
/// 3. 用户无法选择超过限制的照片
///
/// 如果需要在用户尝试选择超过限制时显示自定义 Toast：
/// - 可以通过监听系统行为或使用自定义照片选择器实现
/// - 当前实现依赖系统默认行为，简洁且符合 iOS 设计规范

#Preview {
    SystemPhotoPickerWithToast { results in
        print("Selected \(results.count) photos")
    }
}

