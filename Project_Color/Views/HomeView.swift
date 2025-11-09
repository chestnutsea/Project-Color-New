//
//  HomeView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    // MARK: - 布局常量
    private let imageSize: CGFloat = 300 // 图片大小
    private let scannerTopOffset: CGFloat = 100 // PhotoScanner 上移距离
    
    // 照片模板布局常量（参考 TestPhotosChannel）
    private let photoCardWidth: CGFloat = 150 // 照片卡片宽度
    private let cardCornerRadius: CGFloat = 6
    private let shadowColor = Color.black.opacity(0.25)
    private let shadowRadius: CGFloat = 12
    private let shadowOffsetX: CGFloat = 4
    private let shadowOffsetY: CGFloat = 6
    private let middleAngles: [Double] = [-6, 6]
    private let middleOffsetsX: [CGFloat] = [-25, 25]
    private let bottomAngles: [Double] = [-8, 6, -4]
    private let bottomOffsetsX: [CGFloat] = [-35, 35, -10]
    private let bottomOffsetsY: [CGFloat] = [0, 20, 40]
    
    // 拖拽和处理相关布局常量
    private let arrowSize: CGFloat = 40 // 向上箭头大小
    private let arrowOpacity: Double = 0.5 // 箭头透明度
    private let arrowBelowScannerOffset: CGFloat = 100 // 箭头距离 scanner 底部的距离
    private let fadeOutDuration: Double = 0.3 // 照片堆渐变消失速度
    private let progressBarTopOffset: CGFloat = 50 // 进度条距离 scanner 顶部的距离
    private let photoStackBottomOffset: CGFloat = 40 // 照片堆距离屏幕底部的距离
    
    // MARK: - State
    @State private var showAlbumList = false
    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @StateObject private var selectionManager = PhotoSelectionManager.shared
    
    #if canImport(UIKit)
    @State private var selectedImages: [UIImage] = []
    #endif
    
    // 拖拽相关状态
    @State private var dragOffset: CGSize = .zero
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var photoStackOpacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if selectionManager.selectedAlbums.isEmpty {
                    // 未选择照片：居中显示 PhotoScanner
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            Button(action: handleImageTap) {
                                loadPhotoScannerImage()
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize, height: imageSize)
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        
                        Spacer()
                    }
                } else {
                    // 已选择照片：PhotoScanner + 箭头 + 照片堆
                    VStack(spacing: 0) {
                        // PhotoScanner - 水平居中
                        HStack {
                            Spacer()
                            Button(action: handleImageTap) {
                                loadPhotoScannerImage()
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize, height: imageSize)
                                    .background(
                                        GeometryReader { scannerGeo in
                                            Color.clear.preference(
                                                key: ScannerPositionKey.self,
                                                value: scannerGeo.frame(in: .global)
                                            )
                                        }
                                    )
                            }
                            .buttonStyle(.plain)
                            Spacer()
                        }
                        .padding(.top, scannerTopOffset)
                        
                        Spacer()
                        
                        // 照片模板展示 - 底部居中
                        if !isProcessing && photoStackOpacity > 0 {
                            HStack {
                                Spacer()
                                photoTemplateView
                                    .opacity(photoStackOpacity)
                                    .offset(dragOffset)
                                    .background(
                                        GeometryReader { photoGeo in
                                            Color.clear.preference(
                                                key: PhotoStackPositionKey.self,
                                                value: photoGeo.frame(in: .global)
                                            )
                                        }
                                    )
                                    .gesture(
                                        DragGesture(minimumDistance: 10)
                                            .onChanged { value in
                                                dragOffset = value.translation
                                            }
                                            .onEnded { value in
                                                handleDragEnd(geometry: geometry)
                                            }
                                    )
                                    .onTapGesture {
                                        showAlbumList = true
                                    }
                                Spacer()
                            }
                            .padding(.bottom, photoStackBottomOffset)
                        }
                    }
                }
                
                // 进度条
                if isProcessing {
                    VStack {
                        ProgressView(value: processingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        
                        Spacer()
                    }
                    .padding(.top, scannerTopOffset - progressBarTopOffset)
                }
            }
            .onPreferenceChange(ScannerPositionKey.self) { rect in
                print("Scanner frame updated: \(rect)")
                scannerFrame = rect
            }
            .onPreferenceChange(PhotoStackPositionKey.self) { rect in
                print("Photo stack frame updated: \(rect)")
                photoStackFrame = rect
            }
        }
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
        .onAppear {
            checkPhotoLibraryStatus()
        }
        .onChange(of: selectionManager.selectedAlbums) { _ in
            loadSelectedImages()
            resetDragState()
        }
    }
    
    // MARK: - 存储位置信息
    @State private var scannerFrame: CGRect = .zero
    @State private var photoStackFrame: CGRect = .zero
    
    // MARK: - 拖拽处理
    private func handleDragEnd(geometry: GeometryProxy) {
        // 调试信息
        print("Scanner frame: \(scannerFrame)")
        print("Photo stack frame: \(photoStackFrame)")
        print("Drag offset: \(dragOffset)")
        
        // 检查 frame 是否有效
        guard !scannerFrame.isEmpty && !photoStackFrame.isEmpty else {
            print("Warning: Frame is empty, resetting drag")
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
            return
        }
        
        // 计算拖拽后的照片堆位置
        let draggedPhotoStackFrame = CGRect(
            x: photoStackFrame.origin.x + dragOffset.width,
            y: photoStackFrame.origin.y + dragOffset.height,
            width: photoStackFrame.width,
            height: photoStackFrame.height
        )
        
        print("Dragged photo stack frame: \(draggedPhotoStackFrame)")
        
        // 检测碰撞
        if scannerFrame.intersects(draggedPhotoStackFrame) {
            print("Collision detected! Starting processing...")
            // 有重叠，开始处理
            startProcessing()
        } else {
            print("No collision, bouncing back")
            // 无重叠，弹回原位
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
        }
    }
    
    private func startProcessing() {
        print("=== startProcessing called ===")
        print("Current opacity: \(photoStackOpacity)")
        print("Current isProcessing: \(isProcessing)")
        
        // 立即设置处理状态
        DispatchQueue.main.async {
            // 照片堆渐变消失
            withAnimation(.easeOut(duration: self.fadeOutDuration)) {
                self.photoStackOpacity = 0.0
                self.dragOffset = .zero
            }
            
            print("Animation started - opacity set to 0, dragOffset reset")
            
            // 延迟后开始显示进度条
            DispatchQueue.main.asyncAfter(deadline: .now() + self.fadeOutDuration) {
                print("Starting progress bar")
                self.isProcessing = true
                self.simulateProcessing()
            }
        }
    }
    
    private func simulateProcessing() {
        // 模拟处理进度
        processingProgress = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if processingProgress < 1.0 {
                processingProgress += 0.02
            } else {
                timer.invalidate()
                // 处理完成后的逻辑
                // TODO: 跳转到结果页面或其他操作
            }
        }
    }
    
    private func resetDragState() {
        dragOffset = .zero
        isProcessing = false
        processingProgress = 0.0
        photoStackOpacity = 1.0
    }
    
    // MARK: - 照片模板视图
    @ViewBuilder
    private var photoTemplateView: some View {
        #if canImport(UIKit)
        let count = selectedImages.count
        
        if count == 1 {
            singleCardSection()
        } else if count == 2 {
            doubleCardSection()
        } else {
            tripleCardSection()
        }
        #else
        EmptyView()
        #endif
    }
    
    // MARK: - 相册权限处理
    private func checkPhotoLibraryStatus() {
        photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    private func handleImageTap() {
        switch photoAuthorizationStatus {
        case .authorized, .limited:
            // 已授权，直接进入相册列表
            showAlbumList = true
            
        case .notDetermined:
            // 未决定，请求权限
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    photoAuthorizationStatus = status
                    if status == .authorized || status == .limited {
                        showAlbumList = true
                    }
                }
            }
            
        case .denied, .restricted:
            // 被拒绝或受限，保持在当前页面
            // TODO: 可以添加提示用户去设置中开启权限
            print("相册权限被拒绝")
            
        @unknown default:
            break
        }
    }
    
    // MARK: - 加载选中的照片
    private func loadSelectedImages() {
        #if canImport(UIKit)
        selectedImages.removeAll()
        
        let latestAssets = selectionManager.getLatestPhotos(count: 3)
        
        for asset in latestAssets {
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 800, height: 800)
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        self.selectedImages.append(image)
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - 单张卡片
    private func singleCardSection() -> some View {
        #if canImport(UIKit)
        ZStack {
            if let image = selectedImages.first {
                let aspectRatio = image.size.width / image.size.height
                let imageHeight = photoCardWidth / aspectRatio
                
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                        .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                        .frame(width: photoCardWidth)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .frame(width: photoCardWidth, height: imageHeight)
            } else {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
            }
        }
        #else
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(Color.gray.opacity(0.3))
            .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
        #endif
    }
    
    // MARK: - 两张卡片
    private func doubleCardSection() -> some View {
        #if canImport(UIKit)
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                if i < selectedImages.count {
                    let image = selectedImages[i]
                    let aspectRatio = image.size.width / image.size.height
                    let imageHeight = photoCardWidth / aspectRatio
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: photoCardWidth)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: photoCardWidth, height: imageHeight)
                    .rotationEffect(.degrees(middleAngles[i]))
                    .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
                        .rotationEffect(.degrees(middleAngles[i]))
                        .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
                }
            }
        }
        #else
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
                    .rotationEffect(.degrees(middleAngles[i]))
                    .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
            }
        }
        #endif
    }
    
    // MARK: - 三张卡片
    private func tripleCardSection() -> some View {
        #if canImport(UIKit)
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                if i < selectedImages.count {
                    let image = selectedImages[i]
                    let aspectRatio = image.size.width / image.size.height
                    let imageHeight = photoCardWidth / aspectRatio
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: photoCardWidth)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: photoCardWidth, height: imageHeight)
                    .rotationEffect(.degrees(bottomAngles[i]))
                    .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
                        .rotationEffect(.degrees(bottomAngles[i]))
                        .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
                }
            }
        }
        #else
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: photoCardWidth, height: photoCardWidth * 4/3)
                    .rotationEffect(.degrees(bottomAngles[i]))
                    .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
            }
        }
        #endif
    }
    
    // MARK: - 加载图片
    private func loadPhotoScannerImage() -> Image {
        #if canImport(UIKit)
        // 方法1: 尝试从 AppStyle 文件夹加载
        if let imagePath = Bundle.main.path(forResource: "PhotoScanner", ofType: "png", inDirectory: "AppStyle"),
           let uiImage = UIImage(contentsOfFile: imagePath) {
            return Image(uiImage: uiImage)
        }
        // 方法2: 如果图片在 Assets.xcassets 中，直接使用名称
        if let uiImage = UIImage(named: "PhotoScanner") {
            return Image(uiImage: uiImage)
        }
        // 方法3: 尝试使用完整路径名称
        if let uiImage = UIImage(named: "AppStyle/PhotoScanner") {
            return Image(uiImage: uiImage)
        }
        // 如果都失败，显示占位符
        return Image(systemName: "photo")
        #else
        // macOS 或其他平台
        return Image("PhotoScanner")
        #endif
    }
}

// MARK: - PreferenceKeys for position tracking
struct ScannerPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct PhotoStackPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    HomeView()
}
