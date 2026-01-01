//
//  SystemPhotoPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/10.
//  使用 SwiftUI 原生 PhotosPicker 的照片选择器（隐私模式）
//

import SwiftUI
import PhotosUI

// MARK: - 系统照片选择器（隐私模式）
/// 使用 SwiftUI 原生 PhotosPicker，最多选择 9 张照片
/// ✅ 完全隐私保护：不需要照片库权限，不会触发权限弹窗
/// ✅ 直接加载图片数据，不使用 PHAsset
struct SystemPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 选择完成回调，返回加载好的 UIImage 数组
    var onSelection: ([UIImage]) -> Void
    
    /// 最大选择数量
    private let maxSelection = 9
    
    /// 选中的照片项
    @State private var selectedItems: [PhotosPickerItem] = []
    
    /// 是否正在加载
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    // 加载指示器
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在加载照片...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 照片选择器
                    // ✅ 隐私模式：不指定 photoLibrary 参数
                    // 这样不会触发照片库权限弹窗，完全保护用户隐私
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: maxSelection,
                        matching: .images
                    ) {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("选择照片")
                                .font(.headline)
                            
                            Text(String(format: L10n.PhotoPicker.maxSelection.localized, maxSelection))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("选择照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Common.cancel.localized) {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItems) { newItems in
                guard !newItems.isEmpty else { return }
                
                isLoading = true
                
                Task {
                    var images: [UIImage] = []
                    
                    // ✅ 直接加载图片数据，不使用 PHAsset
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            images.append(uiImage)
                        }
                    }
                    
                    await MainActor.run {
                        isLoading = false
                        
                        if !images.isEmpty {
                            print("📸 SystemPhotoPickerView: 成功加载 \(images.count) 张照片")
                            onSelection(images)
                        }
                        
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 注意事项
/// PhotosPicker 的隐私保护特性：
/// 1. ✅ 不需要照片库访问权限
/// 2. ✅ 不会触发系统权限弹窗
/// 3. ✅ 用户只能看到和选择自己想要的照片
/// 4. ✅ App 只能访问用户选择的照片，其他照片完全不可见
/// 5. ✅ 照片数据由系统管理，App 无法直接访问照片库
///
/// 与 PHPickerViewController 的区别：
/// - PhotosPicker: SwiftUI 原生组件，返回 PhotosPickerItem
/// - PHPickerViewController: UIKit 组件，返回 PHPickerResult（可能包含 assetIdentifier）
///
/// 为什么使用 PhotosPicker：
/// - 避免使用 assetIdentifier 和 PHAsset.fetchAssets（会触发权限检查）
/// - 直接通过 loadTransferable 加载图片数据（无需权限）
/// - 更符合 SwiftUI 的设计理念

#Preview {
    SystemPhotoPickerView { images in
        print("Selected \(images.count) photos")
    }
}

