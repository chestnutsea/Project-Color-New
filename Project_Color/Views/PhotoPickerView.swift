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
        
        // 设置全局的 tint color 为黑色
        UIView.appearance(whenContainedInInstancesOf: [PHPickerViewController.self]).tintColor = .black
        
        // 设置导航栏按钮颜色
        UINavigationBar.appearance(whenContainedInInstancesOf: [PHPickerViewController.self]).tintColor = .black
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [PHPickerViewController.self]).tintColor = .black
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        // 使用 photoLibrary 参数以确保可以获取 assetIdentifier
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 0 // No limit
        configuration.preferredAssetRepresentationMode = .current
        configuration.selection = .ordered // Maintain selection order
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        
        // 设置强调色为黑色（包括按钮和选中标记）
        picker.view.tintColor = .black
        
        // 修改导航栏按钮颜色
        if let navigationBar = picker.navigationController?.navigationBar {
            navigationBar.tintColor = .black
        }
        
        // 使用 UINavigationBarAppearance 来设置按钮颜色
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
        picker.navigationController?.navigationBar.standardAppearance = appearance
        picker.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // 尝试设置选中标记的背景色
        // PHPickerViewController 使用系统的选择样式，我们需要遍历视图层级来修改
                    DispatchQueue.main.async {
            self.customizePickerAppearance(picker.view)
            // 再次尝试设置导航栏
            if let navigationBar = picker.navigationController?.navigationBar {
                navigationBar.tintColor = .black
        }
    }
        
        return picker
}

    // 自定义 Picker 外观
    private func customizePickerAppearance(_ view: UIView) {
        // 遍历所有子视图
        for subview in view.subviews {
            // 查找选中标记的视图（通常是 UIImageView 或特定的系统视图）
            if let imageView = subview as? UIImageView {
                imageView.tintColor = .black
            }
            
            // 查找导航栏
            if let navigationBar = subview as? UINavigationBar {
                navigationBar.tintColor = .black
                // 设置导航栏按钮颜色
                let appearance = UINavigationBarAppearance()
                appearance.configureWithDefaultBackground()
                appearance.buttonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
                navigationBar.standardAppearance = appearance
                navigationBar.scrollEdgeAppearance = appearance
            }
            
            // 查找按钮
            if let button = subview as? UIButton {
                button.tintColor = .black
                button.setTitleColor(.black, for: .normal)
            }
            
            // 递归处理子视图
            customizePickerAppearance(subview)
        }
        
        // 设置整个视图的 tintColor
        view.tintColor = .black
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
