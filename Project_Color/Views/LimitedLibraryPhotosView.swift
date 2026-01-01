//
//  LimitedLibraryPhotosView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/27.
//  有限访问模式的照片网格界面
//

import SwiftUI
import Photos
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct LimitedLibraryPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authorizedAssets: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []
    @State private var limitedLibraryObserver = LimitedLibraryChangeObserver()
    @State private var showLimitToast = false
    
    private let maxSelectionCount = 9
    
    let onPhotosSelected: ([PHAsset]) -> Void
    
    init(onPhotosSelected: @escaping ([PHAsset]) -> Void) {
        self.onPhotosSelected = onPhotosSelected
        // 立即开始预加载照片
        _authorizedAssets = State(initialValue: Self.loadPhotosSync())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3),
                        spacing: 1
                    ) {
                        // 加号按钮
                        Button(action: { presentLimitedLibraryPicker() }) {
                            GeometryReader { geo in
                                Image(systemName: "plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                    .frame(width: geo.size.width, height: geo.size.width)
                                    .background(Color.gray.opacity(0.1))
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        
                        // 授权照片
                        ForEach(authorizedAssets, id: \.localIdentifier) { asset in
                            PhotoGridCell(
                                asset: asset,
                                isSelected: selectedAssets.contains(asset.localIdentifier)
                            )
                            .onTapGesture {
                                toggleSelection(asset.localIdentifier)
                            }
                        }
                    }
                }
                
                // Toast 提示
                if showLimitToast {
                    VStack {
                        Spacer()
                        
                        Text(String(format: L10n.LimitedLibrary.maxSelectionToast.localized, maxSelectionCount))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                        
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(1000)
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(format: L10n.LimitedLibrary.analyzeButton.localized, selectedAssets.count)) {
                        startAnalysis()
                    }
                    .disabled(selectedAssets.isEmpty)
                }
            }
        }
        .onAppear {
            limitedLibraryObserver.onChange = { loadAuthorizedAssets() }
            PHPhotoLibrary.shared().register(limitedLibraryObserver)
            // 如果预加载失败或照片为空，再次尝试加载
            if authorizedAssets.isEmpty {
                loadAuthorizedAssets()
            }
        }
        .onDisappear {
            PHPhotoLibrary.shared().unregisterChangeObserver(limitedLibraryObserver)
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelection(_ identifier: String) {
        if selectedAssets.contains(identifier) {
            // 取消选择
            selectedAssets.remove(identifier)
        } else {
            // 检查是否超出限制
            if selectedAssets.count >= maxSelectionCount {
                showLimitToastMessage()
                return
            }
            selectedAssets.insert(identifier)
        }
    }
    
    private func showLimitToastMessage() {
        // 显示 Toast
        withAnimation(.easeInOut(duration: 0.2)) {
            showLimitToast = true
        }
        
        // 1 秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showLimitToast = false
            }
        }
    }
    
    private func startAnalysis() {
        let selected = authorizedAssets.filter { selectedAssets.contains($0.localIdentifier) }
        onPhotosSelected(selected)
        dismiss()
    }
    
    private func loadAuthorizedAssets() {
        DispatchQueue.global(qos: .userInitiated).async {
            let assets = Self.loadPhotosSync()
            
            print("📸 LimitedLibraryPhotosView: 获取到 \(assets.count) 张授权照片")
            
            DispatchQueue.main.async {
                self.authorizedAssets = assets
                print("📸 LimitedLibraryPhotosView: UI 已更新，显示 \(self.authorizedAssets.count) 张照片")
            }
        }
    }
    
    // 同步加载照片（用于初始化时预加载）
    private static func loadPhotosSync() -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        // 只获取静态图片，排除视频和 Live Photos
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            // 双重检查：确保只添加图片类型
            if asset.mediaType == .image {
                assets.append(asset)
            }
        }
        
        print("📸 LimitedLibraryPhotosView: 预加载了 \(assets.count) 张授权照片（仅图片）")
        return assets
    }

    private func presentLimitedLibraryPicker() {
        guard let presenter = UIApplication.shared.topMostViewController() else { return }
        DispatchQueue.main.async {
            if #available(iOS 14, *) {
                PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
            }
        }
    }
}

// MARK: - Photo Grid Cell

struct PhotoGridCell: View {
    let asset: PHAsset
    let isSelected: Bool
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if let image = thumbnail {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: geometry.size.width)
                        .overlay(
                            ProgressView()
                        )
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 20, height: 20)
                        )
                        .padding(8)
                }
            }
            .onAppear {
                loadThumbnail(width: geometry.size.width)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
    }
    
    private func loadThumbnail(width: CGFloat) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false
        
        manager.requestImage(
            for: asset,
            targetSize: CGSize(width: width * 2, height: width * 2),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LimitedLibraryPhotosView(onPhotosSelected: { assets in
        print("Selected \(assets.count) photos")
    })
}

#if canImport(UIKit)
private class LimitedLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver {
    var onChange: (() -> Void)?
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.onChange?()
        }
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let scenes = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        let window = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        var root = window?.rootViewController
        while let presented = root?.presentedViewController {
            root = presented
        }
        return root
    }
}
#endif

