//
//  PhotoCardCarousel.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  照片卡片轮播组件
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Layout Constants
private enum PhotoCarouselLayout {
    static let photoHeightRatio: CGFloat = 0.8  // 照片高度占展示区域的比例
    static let cardCornerRadius: CGFloat = 10   // 照片圆角
    static let cardShadowRadius: CGFloat = 15
    static let maxWidthRatio: CGFloat = 0.9     // 照片最大宽度占屏幕宽度的比例
    static let tiltThreshold: CGFloat = 60   // Tilt/Swipe 切换阈值（降低以更容易触发）
    static let tiltDivisor: CGFloat = 15     // Tilt 旋转灵敏度
    static let swipeDistance: CGFloat = 0.5  // 照片切换滑动距离倍数（缩短距离）
}

struct PhotoCardCarousel: View {
    let photoInfos: [PhotoColorInfo]
    let displayAreaHeight: CGFloat  // 展示区域的高度（屏幕高度的 1/3）
    
    @State private var currentIndex: Int = 0
    @State private var loadedImages: [String: UIImage] = [:]  // 缓存加载的图片
    @State private var loadedAssets: [String: PHAsset] = [:]  // 缓存加载的 assets
    
    // Swipe 状态（仅左右滑动）
    @State private var cardOffset: CGFloat = 0
    
    private var maxPhotoHeight: CGFloat {
        displayAreaHeight * PhotoCarouselLayout.photoHeightRatio
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let threshold = PhotoCarouselLayout.tiltThreshold
            
            let drag = DragGesture()
                .onChanged { value in
                    let dx = value.translation.width
                    // 只处理水平滑动
                    cardOffset = dx
                }
                .onEnded { value in
                    let dx = value.translation.width
                    
                    if dx > threshold {
                        // 向右滑 → 上一张
                        swipeToPrevious(width: width)
                    } else if dx < -threshold {
                        // 向左滑 → 下一张
                        swipeToNext(width: width)
                    } else {
                        // 回弹
                        withAnimation(.spring()) {
                            cardOffset = 0
                        }
                    }
                }
            
            ZStack {
                if currentIndex < photoInfos.count {
                    let photoInfo = photoInfos[currentIndex]
                    PhotoCardView(
                        assetIdentifier: photoInfo.assetIdentifier,
                        asset: loadedAssets[photoInfo.assetIdentifier],
                        maxPhotoHeight: maxPhotoHeight,
                        maxPhotoWidth: width * PhotoCarouselLayout.maxWidthRatio,
                        loadedImage: loadedImages[photoInfo.assetIdentifier]
                    )
                    .id(photoInfo.assetIdentifier)  // 强制重新渲染
                    .offset(x: cardOffset)
                    .gesture(drag)
                    .onAppear {
                        loadAssetAndImageIfNeeded(identifier: photoInfo.assetIdentifier)
                        // 预加载相邻照片
                        preloadAdjacentPhotos()
                    }
                }
            }
            .frame(width: width, height: displayAreaHeight)
            .frame(maxWidth: .infinity)  // 确保居中
        }
        .frame(height: displayAreaHeight)
    }
    
    // MARK: - 切换到下一张（左滑，从右侧进入）
    private func swipeToNext(width: CGFloat) {
        guard currentIndex < photoInfos.count - 1 else {
            // 已经是最后一张，回弹
            withAnimation(.spring()) {
                cardOffset = 0
            }
            return
        }
        
        // 当前照片向左滑出
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            cardOffset = -width * PhotoCarouselLayout.swipeDistance
        }
        
        // 切换到下一张
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentIndex += 1
            cardOffset = width * PhotoCarouselLayout.swipeDistance  // 新照片从右侧开始
            
            // 新照片滑入到中心
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                cardOffset = 0
            }
            preloadAdjacentPhotos()
        }
    }
    
    // MARK: - 切换到上一张（右滑，从左侧进入）
    private func swipeToPrevious(width: CGFloat) {
        guard currentIndex > 0 else {
            // 已经是第一张，回弹
            withAnimation(.spring()) {
                cardOffset = 0
            }
            return
        }
        
        // 当前照片向右滑出
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            cardOffset = width * PhotoCarouselLayout.swipeDistance
        }
        
        // 切换到上一张
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentIndex -= 1
            cardOffset = -width * PhotoCarouselLayout.swipeDistance  // 新照片从左侧开始
            
            // 新照片滑入到中心
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                cardOffset = 0
            }
            preloadAdjacentPhotos()
        }
    }
    
    // MARK: - 预加载相邻照片
    private func preloadAdjacentPhotos() {
        // 预加载前一张
        if currentIndex > 0 {
            let prevIdentifier = photoInfos[currentIndex - 1].assetIdentifier
            loadAssetAndImageIfNeeded(identifier: prevIdentifier)
        }
        
        // 预加载后一张
        if currentIndex < photoInfos.count - 1 {
            let nextIdentifier = photoInfos[currentIndex + 1].assetIdentifier
            loadAssetAndImageIfNeeded(identifier: nextIdentifier)
        }
    }
    
    private func loadAssetAndImageIfNeeded(identifier: String) {
        // 如果已经加载过，直接返回
        guard loadedAssets[identifier] == nil else {
            return
        }
        
        // 通过 identifier 获取 PHAsset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        DispatchQueue.main.async {
            loadedAssets[identifier] = asset
        }
        
        // 加载图片
        guard loadedImages[identifier] == nil else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        // 使用一个合理的固定尺寸加载图片（足够大以保证质量）
        let targetSize = CGSize(
            width: 800,  // 足够大的尺寸
            height: 600  // 4:3 比例
        )
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    loadedImages[identifier] = image
                }
            }
        }
    }
}

// MARK: - Photo Card View
private struct PhotoCardView: View {
    let assetIdentifier: String
    let asset: PHAsset?
    let maxPhotoHeight: CGFloat
    let maxPhotoWidth: CGFloat
    let loadedImage: UIImage?
    
    // 计算照片实际显示尺寸（保持原始宽高比）
    private var displaySize: CGSize {
        guard let image = loadedImage else {
            // 默认占位符尺寸
            return CGSize(width: maxPhotoWidth * 0.6, height: maxPhotoHeight)
        }
        
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let aspectRatio = imageWidth / imageHeight
        
        // 根据宽高比计算实际显示尺寸
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        if aspectRatio > 1 {
            // 横向照片：优先适配宽度
            displayWidth = min(maxPhotoWidth, maxPhotoHeight * aspectRatio)
            displayHeight = displayWidth / aspectRatio
            
            // 如果高度超出限制，则适配高度
            if displayHeight > maxPhotoHeight {
                displayHeight = maxPhotoHeight
                displayWidth = displayHeight * aspectRatio
            }
        } else {
            // 纵向或正方形照片：优先适配高度
            displayHeight = maxPhotoHeight
            displayWidth = displayHeight * aspectRatio
            
            // 如果宽度超出限制，则适配宽度
            if displayWidth > maxPhotoWidth {
                displayWidth = maxPhotoWidth
                displayHeight = displayWidth / aspectRatio
            }
        }
        
        return CGSize(width: displayWidth, height: displayHeight)
    }
    
    var body: some View {
        ZStack {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()  // 改为 fit 以保持原始宽高比
                    .frame(width: displaySize.width, height: displaySize.height)
                    .clipShape(RoundedRectangle(cornerRadius: PhotoCarouselLayout.cardCornerRadius))
                    .shadow(radius: PhotoCarouselLayout.cardShadowRadius)
            } else {
                // 加载中占位符
                RoundedRectangle(cornerRadius: PhotoCarouselLayout.cardCornerRadius)
                    .fill(Color(white: 0.85))
                    .frame(width: displaySize.width, height: displaySize.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
                    .shadow(radius: PhotoCarouselLayout.cardShadowRadius)
            }
        }
        .frame(width: displaySize.width, height: displaySize.height)
        .contentShape(Rectangle())  // 限制点击区域为实际内容
    }
}

// MARK: - Fullscreen Photo Viewer
struct FullscreenPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    
    let photoInfos: [PhotoColorInfo]
    let initialIndex: Int
    @Binding var loadedImages: [String: UIImage]
    @Binding var loadedAssets: [String: PHAsset]
    
    @State private var currentIndex: Int
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var cardOffset: CGFloat = 0
    
    init(photoInfos: [PhotoColorInfo], initialIndex: Int, loadedImages: Binding<[String: UIImage]>, loadedAssets: Binding<[String: PHAsset]>) {
        self.photoInfos = photoInfos
        self.initialIndex = initialIndex
        self._loadedImages = loadedImages
        self._loadedAssets = loadedAssets
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let width = geometry.size.width
                let threshold = PhotoCarouselLayout.tiltThreshold
                
                let drag = DragGesture()
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        
                        if abs(dx) < threshold {
                            // Tilt 模式（小范围）
                            rotationY = Double(dx / PhotoCarouselLayout.tiltDivisor)
                            rotationX = Double(-dy / PhotoCarouselLayout.tiltDivisor)
                        } else {
                            // Swipe 模式（大范围）
                            cardOffset = dx
                        }
                    }
                    .onEnded { value in
                        let dx = value.translation.width
                        
                        if dx > threshold {
                            // 向右滑 → 上一张
                            swipeToPrevious(width: width)
                        } else if dx < -threshold {
                            // 向左滑 → 下一张
                            swipeToNext(width: width)
                        } else {
                            // 回弹
                            withAnimation(.spring()) {
                                rotationX = 0
                                rotationY = 0
                                cardOffset = 0
                            }
                        }
                    }
                
                ZStack {
                    // 黑色背景
                    Color.black.ignoresSafeArea()
                    
                    if currentIndex < photoInfos.count {
                        let photoInfo = photoInfos[currentIndex]
                        
                        if let image = loadedImages[photoInfo.assetIdentifier] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: width * 0.9, maxHeight: geometry.size.height * 0.8)
                                .clipShape(RoundedRectangle(cornerRadius: PhotoCarouselLayout.cardCornerRadius))
                                .shadow(radius: PhotoCarouselLayout.cardShadowRadius)
                                .id(photoInfo.assetIdentifier)  // 强制重新渲染
                                .rotation3DEffect(.degrees(rotationX), axis: (x: 1, y: 0, z: 0))
                                .rotation3DEffect(.degrees(rotationY), axis: (x: 0, y: 1, z: 0))
                                .offset(x: cardOffset)
                                .highPriorityGesture(drag)
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // 确保居中
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
        }
    }
    
    // MARK: - 切换到下一张（左滑，从右侧进入）
    private func swipeToNext(width: CGFloat) {
        guard currentIndex < photoInfos.count - 1 else {
            withAnimation(.spring()) {
                rotationX = 0
                rotationY = 0
                cardOffset = 0
            }
            return
        }
        
        // 当前照片向左滑出
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            cardOffset = -width * PhotoCarouselLayout.swipeDistance
        }
        
        // 切换到下一张
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentIndex += 1
            cardOffset = width * PhotoCarouselLayout.swipeDistance  // 新照片从右侧开始
            rotationX = 0
            rotationY = 0
            
            // 新照片滑入到中心
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                cardOffset = 0
            }
        }
    }
    
    // MARK: - 切换到上一张（右滑，从左侧进入）
    private func swipeToPrevious(width: CGFloat) {
        guard currentIndex > 0 else {
            withAnimation(.spring()) {
                rotationX = 0
                rotationY = 0
                cardOffset = 0
            }
            return
        }
        
        // 当前照片向右滑出
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            cardOffset = width * PhotoCarouselLayout.swipeDistance
        }
        
        // 切换到上一张
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            currentIndex -= 1
            cardOffset = -width * PhotoCarouselLayout.swipeDistance  // 新照片从左侧开始
            rotationX = 0
            rotationY = 0
            
            // 新照片滑入到中心
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                cardOffset = 0
            }
        }
    }
}

#Preview {
    // Preview placeholder
    Text("PhotoCardCarousel Preview")
}

