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
    static let swipeThreshold: CGFloat = 30     // 轮播图切换滑动阈值（滑动超过此距离触发切换）
    static let tiltDivisor: CGFloat = 15        // Tilt 旋转灵敏度
    static let swipeDistance: CGFloat = 0.5     // 照片切换滑动距离倍数（缩短距离）
}

struct PhotoCardCarousel: View {
    let photoInfos: [PhotoColorInfo]
    let displayAreaHeight: CGFloat  // 展示区域的高度（屏幕高度的 1/3）
    
    // 全屏查看回调（由父视图处理）
    var onFullScreenRequest: ((Int) -> Void)?
    
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
            let threshold = PhotoCarouselLayout.swipeThreshold
            
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
                // 透明背景，用于捕获整个区域的手势
                Color.clear.contentShape(Rectangle())
                
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
                    .onTapGesture {
                        // 点击进入全屏查看（通知父视图）
                        onFullScreenRequest?(currentIndex)
                    }
                    .onAppear {
                        loadAssetAndImageIfNeeded(identifier: photoInfo.assetIdentifier)
                        // 预加载相邻照片
                        preloadAdjacentPhotos()
                    }
                }
            }
            .frame(width: width, height: displayAreaHeight)
            .frame(maxWidth: .infinity)  // 确保居中
            .contentShape(Rectangle())  // 让整个区域响应手势
            .highPriorityGesture(drag)  // 使用高优先级手势，优先于外层 TabView
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

// MARK: - 全屏照片查看（支持左右滑动切换、双击缩放、右上角关闭）

struct CarouselFullScreenPhotoView: View {
    let photoInfos: [PhotoColorInfo]
    @Binding var currentIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
            ZStack {
            // 黑色背景
                Color.black
                    .ignoresSafeArea()
                
            // 照片容器（支持左右滑动切换）
                TabView(selection: $currentIndex) {
                    ForEach(Array(photoInfos.enumerated()), id: \.element.assetIdentifier) { index, photoInfo in
                    FullScreenPhotoItemView(assetIdentifier: photoInfo.assetIdentifier)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
            // 右上角关闭按钮
                VStack {
                    HStack {
                        Spacer()
                    Button(action: { onDismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.9), .black.opacity(0.3))
                                .padding(20)
                        }
                    }
                    Spacer()
                }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }
}

// MARK: - 全屏单张照片视图（支持双击缩放、放大后拖拽查看）

private struct FullScreenPhotoItemView: View {
    let assetIdentifier: String
    
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(scale > 1.0 ? dragGesture : nil)
                        .simultaneousGesture(magnificationGesture)
                        .simultaneousGesture(doubleTapGesture)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            loadImage()
            }
    }
    
    // 双击手势：快速放大/缩小
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.0
                    }
                }
            }
    }
    
    // 缩放手势
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), maxScale)
            }
            .onEnded { _ in
                lastScale = 1.0
                // 如果缩放接近 1，回到 1
                if scale < 1.1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
    
    // 拖拽手势（仅放大状态可用，用于查看图片不同区域）
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                // 限制偏移范围
                let maxOffset = (scale - 1) * 200
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset.width = min(max(offset.width, -maxOffset), maxOffset)
                    offset.height = min(max(offset.height, -maxOffset), maxOffset)
                }
                lastOffset = offset
            }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else { return }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            let screenScale = UIScreen.main.scale
            let targetSize = CGSize(
                width: UIScreen.main.bounds.width * screenScale,
                height: UIScreen.main.bounds.height * screenScale
            )
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}

// MARK: - 旧版全屏查看（保留兼容）
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
                let threshold = PhotoCarouselLayout.swipeThreshold
                
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

