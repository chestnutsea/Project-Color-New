//
//  FullLibraryPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/27.
//  完全访问权限下的系统相册选择器
//

import SwiftUI
import PhotosUI

struct FullLibraryPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhotosSelected: ([PHAsset]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        // 只显示静态图片，排除 Live Photos 和视频
        configuration.filter = PHPickerFilter.images
        configuration.selectionLimit = 9  // 最多选择9张
        configuration.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: FullLibraryPickerView
        
        init(_ parent: FullLibraryPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard !results.isEmpty else {
                print("📸 FullLibraryPickerView: 用户取消选择")
                return
            }
            
            print("📸 FullLibraryPickerView: 用户选择了 \(results.count) 张照片")
            
            // 从 PHPickerResult 获取 PHAsset
            let identifiers = results.compactMap { $0.assetIdentifier }
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }
            
            parent.onPhotosSelected(assets)
        }
    }
}

#Preview {
    FullLibraryPickerView(onPhotosSelected: { assets in
        print("Selected \(assets.count) photos")
    })
}

