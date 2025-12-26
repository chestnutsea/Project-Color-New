//
//  PhotoPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  使用 PHPickerViewController 的照片选择器
//

import SwiftUI
import PhotosUI

struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var onSelection: ([PHPickerResult]) -> Void
    
    init(onSelection: @escaping ([PHPickerResult]) -> Void) {
        self.onSelection = onSelection
        
        // 使用系统默认的蓝色 tintColor（不设置 appearance 即为默认）
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        // ✅ 隐私模式：不指定 photoLibrary 参数
        // 这样不会触发照片库权限弹窗，完全保护用户隐私
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0 // No limit
        configuration.preferredAssetRepresentationMode = .current
        configuration.selection = .ordered // Maintain selection order
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        
        // ✅ 设置照片选择器的强调色为系统蓝色
        picker.view.tintColor = UIColor.systemBlue
        
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            if !results.isEmpty {
                print("📸 PhotoPickerView: 用户选择了 \(results.count) 张照片")
                parent.onSelection(results)
            } else {
                print("📸 PhotoPickerView: 用户取消选择")
            }
        }
    }
}

#Preview {
    PhotoPickerView(onSelection: { results in
        print("Selected \(results.count) photos")
    })
}
