//
//  LimitedLibraryPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/27.
//  封装系统的有限照片库选择器
//

import SwiftUI
import Photos
import PhotosUI

struct LimitedLibraryPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onPhotosUpdated: () -> Void
    
    func makeUIViewController(context: Context) -> LimitedPickerViewController {
        let viewController = LimitedPickerViewController()
        viewController.view.backgroundColor = .clear
        viewController.modalPresentationStyle = .overCurrentContext
        viewController.onDismiss = {
            onPhotosUpdated()
            dismiss()
        }
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: LimitedPickerViewController, context: Context) {
        // No update needed
    }
}

class LimitedPickerViewController: UIViewController, PHPhotoLibraryChangeObserver {
    var onDismiss: (() -> Void)?
    private var hasPresented = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        PHPhotoLibrary.shared().register(self)
        
        // 立即弹出系统选择器，避免显示空白页面
        DispatchQueue.main.async { [weak self] in
            self?.presentLimitedPicker()
        }
    }
    
    private func presentLimitedPicker() {
        guard !hasPresented else { return }
        hasPresented = true
        
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
        }
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 照片库发生变化时，刷新照片列表并关闭
        DispatchQueue.main.async { [weak self] in
            self?.onDismiss?()
            self?.dismiss(animated: true)
        }
    }
}

#Preview {
    LimitedLibraryPickerView(onPhotosUpdated: {
        print("Photos updated")
    })
}
