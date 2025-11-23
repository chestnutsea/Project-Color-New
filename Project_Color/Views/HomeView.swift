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
    private let scannerTopOffset: CGFloat = 300 // PhotoScanner 上移距离
    
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
    private let photoStackBottomOffset: CGFloat = 80 // 照片堆距离屏幕底部的距离
    
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
    
    // 颜色分析相关
    @State private var analysisProgress = AnalysisProgress()
    @State private var analysisResult: AnalysisResult?
    @State private var showAnalysisResult = false
    @State private var showAnalysisHistory = false  // Phase 3: 历史记录
    @State private var showAnalysisSettings = false  // Phase 5: 分析设置
    @State private var showCollectedTags = false  // Vision 标签库
    @State private var showShareSheet = false  // 导出分享
    @State private var shareURL: URL?  // 分享文件 URL
    private let analysisPipeline = SimpleAnalysisPipeline()
    private let progressThrottler = ProgressThrottler(interval: 0.15)
    
#if DEBUG
    private let enableVerboseLogging = false
#endif
    
    private func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        if enableVerboseLogging {
            print(message())
        }
#endif
    }
    
    // 图像类型选择弹窗
    @State private var showImageTypeAlert = false
    @State private var selectedImageType: ImageType = .personalWork
    
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
                
                // Phase 3 & 5: 历史记录和设置按钮
                if !isProcessing {
                    VStack {
                        HStack {
                            Spacer()
                            
                            // Vision 标签库菜单
                            Menu {
                                Button(action: {
                                    showCollectedTags = true
                                }) {
                                    Label("查看标签库", systemImage: "tag.fill")
                                }
                                
                                Button(action: {
                                    exportTags()
                                }) {
                                    Label("导出标签", systemImage: "square.and.arrow.down")
                                }
                                .disabled(TagCollector.shared.count() == 0)
                            } label: {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 8)
                            
                            // Phase 5: 设置按钮
                            Button(action: {
                                showAnalysisSettings = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 8)
                            
                            // Phase 3: 历史记录按钮
                            Button(action: {
                                showAnalysisHistory = true
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 24))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing)
                        }
                        Spacer()
                    }
                }
                
                // 进度条
                if isProcessing {
                    VStack(spacing: 12) {
                        Text(analysisProgress.currentStage)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(analysisProgress.progressText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        AnalysisProgressBar(progress: processingProgress)
                            .frame(width: 250, height: 8)
                        
                        HStack(spacing: 16) {
                            Text(analysisProgress.percentageText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !analysisProgress.timeRemainingText.isEmpty {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(analysisProgress.timeRemainingText)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Phase 5: 详细进度信息
                        if !analysisProgress.detailText.isEmpty {
                            Text(analysisProgress.detailText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, 4)
                        }
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.95))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, scannerTopOffset - progressBarTopOffset)
                }
            }
                .onPreferenceChange(ScannerPositionKey.self) { rect in
                    debugLog("Scanner frame updated: \(rect)")
                    scannerFrame = rect
                }
                .onPreferenceChange(PhotoStackPositionKey.self) { rect in
                    debugLog("Photo stack frame updated: \(rect)")
                    photoStackFrame = rect
                }
        }
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
        .sheet(isPresented: $showAnalysisResult) {
            if let result = analysisResult {
                AnalysisResultView(result: result)
            }
        }
        .sheet(isPresented: $showAnalysisHistory) {
            AnalysisHistoryView()
        }
        .sheet(isPresented: $showAnalysisSettings) {
            AnalysisSettingsView()
        }
        .sheet(isPresented: $showCollectedTags) {
            CollectedTagsView()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                #if canImport(UIKit)
                ShareSheet(activityItems: [url])
                #else
                EmptyView()
                #endif
            }
        }
        .imageTypeSelectionAlert(isPresented: $showImageTypeAlert) { result in
            handleImageTypeSelection(result)
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
        debugLog("=== handleDragEnd called ===")
        debugLog("Screen size: \(geometry.size.width) x \(geometry.size.height)")
        debugLog("Drag offset: \(dragOffset)")
        
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        // 计算scanner的范围（基于布局常量，scanner水平居中）
        let scannerTop = scannerTopOffset  // 100
        let scannerBottom = scannerTopOffset + imageSize  // 100 + 300 = 400
        let scannerLeft = (screenWidth - imageSize) / 2  // 居中
        let scannerRight = scannerLeft + imageSize
        
        // 估算照片堆的初始位置（底部居中）
        let photoStackWidth: CGFloat = photoCardWidth + 100  // 照片宽度 + 偏移容差
        let photoStackHeight: CGFloat = 200  // 估算高度
        let photoStackInitialX = (screenWidth - photoStackWidth) / 2
        let photoStackInitialY = screenHeight - photoStackBottomOffset - photoStackHeight / 2
        
        // 计算拖拽后的照片堆位置
        let photoStackDraggedX = photoStackInitialX + dragOffset.width
        let photoStackDraggedY = photoStackInitialY + dragOffset.height
        let photoStackDraggedRight = photoStackDraggedX + photoStackWidth
        let photoStackDraggedBottom = photoStackDraggedY + photoStackHeight
        
        debugLog("Scanner range: X[\(Int(scannerLeft))-\(Int(scannerRight))] Y[\(Int(scannerTop))-\(Int(scannerBottom))]")
        debugLog("Photo stack dragged: X[\(Int(photoStackDraggedX))-\(Int(photoStackDraggedRight))] Y[\(Int(photoStackDraggedY))-\(Int(photoStackDraggedBottom))]")
        
        // 判断是否有重合（X轴和Y轴都要检查）
        let hasXOverlap = photoStackDraggedRight > scannerLeft && photoStackDraggedX < scannerRight
        let hasYOverlap = photoStackDraggedBottom > scannerTop && photoStackDraggedY < scannerBottom
        
        debugLog("X overlap: \(hasXOverlap), Y overlap: \(hasYOverlap)")
        
        if hasXOverlap && hasYOverlap {
            debugLog("✅ Photo stack overlaps with scanner! Starting processing...")
            startProcessing()
            return
        }
        
        // 如果没有重合，弹回原位
        debugLog("❌ No overlap detected")
        if !hasYOverlap {
            debugLog("   Y: Photo stack (\(Int(photoStackDraggedY))) needs to reach scanner (\(Int(scannerBottom)))")
        }
        if !hasXOverlap {
            debugLog("   X: Photo stack needs better horizontal alignment")
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            dragOffset = .zero
        }
    }
    
    private func startProcessing() {
        debugLog("=== startProcessing called ===")
        debugLog("Current opacity: \(photoStackOpacity)")
        debugLog("Current isProcessing: \(isProcessing)")
        
        // 显示图像类型选择弹窗
        showImageTypeAlert = true
    }
    
    private func handleImageTypeSelection(_ result: ImageTypeSelectionResult) {
        switch result {
        case .selected(let imageType):
            selectedImageType = imageType
            debugLog("✅ 用户选择: \(imageType == .personalWork ? "我的作品" : "其他图像")")
            
            // 开始处理动画
            DispatchQueue.main.async {
                // 照片堆渐变消失
                withAnimation(.easeOut(duration: self.fadeOutDuration)) {
                    self.photoStackOpacity = 0.0
                    self.dragOffset = .zero
                }
                
                debugLog("Animation started - opacity set to 0, dragOffset reset")
                
                // 延迟后开始显示进度条并开始分析
                DispatchQueue.main.asyncAfter(deadline: .now() + self.fadeOutDuration) {
                    debugLog("Starting analysis")
                    self.isProcessing = true
                    self.startColorAnalysis()
                }
            }
            
        case .cancelled:
            debugLog("❌ 用户取消分析")
            // 重置拖拽状态
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                dragOffset = .zero
            }
        }
    }
    
    private func startColorAnalysis() {
        // 重置进度状态（立即显示"准备中"）
        analysisProgress = AnalysisProgress(
            currentPhoto: 0,
            totalPhotos: 0,
            currentStage: "准备照片数据...",
            overallProgress: 0.0
        )
        processingProgress = 0.0
        analysisResult = nil
        progressThrottler.reset()
        
        Task {
            // 在后台线程获取照片资产（避免阻塞主线程）
            let assetsWithAlbums = await Task.detached(priority: .userInitiated) {
                self.selectionManager.getLatestPhotosWithAlbums(count: 1000)
            }.value
            
            let assets = assetsWithAlbums.map { $0.asset }
            
            guard !assets.isEmpty else {
                print("No assets to analyze")
                await MainActor.run {
                    self.isProcessing = false
                }
                return
            }
            
            // 更新进度：照片数据准备完成
            await MainActor.run {
                self.analysisProgress = AnalysisProgress(
                    currentPhoto: 0,
                    totalPhotos: assets.count,
                    currentStage: "开始分析...",
                    overallProgress: 0.01
                )
                self.processingProgress = 0.01
            }
            
            // 获取相册信息（如果只选中了一个相册）
            var albumInfoMap: [String: (identifier: String, name: String)] = [:]
            if selectedImageType == .personalWork {
                for entry in assetsWithAlbums {
                    guard let album = entry.album else { continue }
                    albumInfoMap[entry.asset.localIdentifier] = (album.id, album.title)
                }
                if albumInfoMap.isEmpty {
                    debugLog("📂 未记录相册信息 (选中 \(selectionManager.selectedAlbums.count) 个相册)")
                } else {
                    debugLog("📂 记录相册映射: \(albumInfoMap.count) 张")
                }
            }
            
            let throttledHandler: (AnalysisProgress) -> Void = { progress in
                let force = progress.overallProgress >= 0.99
                if self.progressThrottler.shouldEmit(force: force) {
                    Task { @MainActor in
                        self.analysisProgress = progress
                        self.processingProgress = progress.overallProgress
                    }
                }
            }
            
            let result = await analysisPipeline.analyzePhotos(
                assets: assets,
                albumInfoMap: albumInfoMap,
                progressHandler: throttledHandler
            )
            
            // 设置图像类型标记
            await MainActor.run {
                result.isPersonalWork = (selectedImageType == .personalWork)
            }
            
            // 分析完成
            await MainActor.run {
                self.analysisResult = result
                self.isProcessing = false
                
                // 短暂延迟后跳转到结果页
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showAnalysisResult = true
                }
            }
        }
    }
    
    private func resetDragState() {
        dragOffset = .zero
        isProcessing = false
        processingProgress = 0.0
        photoStackOpacity = 1.0
        analysisProgress = AnalysisProgress()
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
    
    // MARK: - 导出标签
    private func exportTags() {
        #if canImport(UIKit)
        let tagStats = TagCollector.shared.exportStats()
        
        guard !tagStats.isEmpty else {
            print("⚠️ 没有标签可导出")
            return
        }
        
        // 创建文件内容
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        var content = "Vision 标签导出\n"
        content += "导出时间: \(dateString)\n"
        content += "唯一标签数: \(tagStats.count)\n"
        content += "总标签数: \(TagCollector.shared.totalCount())\n"
        content += "\n"
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        content += "\n"
        content += String(format: "%-30s %s\n", "标签", "次数")
        content += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        content += "\n"
        
        // 添加所有标签（带次数）
        for tagStat in tagStats {
            content += String(format: "%-30s %d\n", tagStat.tag, tagStat.count)
        }
        
        // 创建临时文件
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "vision_tags_\(fileDateFormatter.string(from: Date())).txt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // 写入文件
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            
            // 显示分享界面
            shareURL = fileURL
            showShareSheet = true
        } catch {
            print("❌ 导出失败: \(error.localizedDescription)")
        }
        #endif
    }
}

// MARK: - Custom Views
private struct AnalysisProgressBar: View {
    var progress: Double
    var trackColor: Color = Color.gray.opacity(0.2)
    var fillColor: Color = Color.blue
    
    var body: some View {
        GeometryReader { geometry in
            let fraction = max(0, min(progress, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                Capsule()
                    .fill(fillColor)
                    .frame(width: geometry.size.width * CGFloat(fraction))
            }
        }
        .frame(height: 8)
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
