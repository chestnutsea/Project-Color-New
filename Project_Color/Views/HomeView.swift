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
    private struct SelectedAlbumContext {
        let id: String
        let name: String
    }
    
    // MARK: - 布局常量
    private let imageSize: CGFloat = 400 // 图片大小
    private let scannerTopOffset: CGFloat = 30 // PhotoScanner 上移距离
    
    // PhotoScanner 阴影常量
    private let scannerShadowColor = Color.black.opacity(0.5)
    private let scannerShadowRadius: CGFloat = 15
    private let scannerShadowOffsetX: CGFloat = 8
    private let scannerShadowOffsetY: CGFloat = 8
    
    // 照片模板布局常量（参考 TestPhotosChannel）
    private let photoCardBaseSize: CGFloat = 150 // 照片卡片基础尺寸（纵向图固定宽度，横向图固定高度）
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
    private let progressBarBelowScannerOffset: CGFloat = 100 // 进度条距离 scanner 底部的距离
    private let progressBarWidth: CGFloat = 200 // 进度条宽度
    private let progressBarHeight: CGFloat = 4 // 进度条高度
    private let photoStackBottomOffset: CGFloat = 80 // 照片堆距离屏幕底部的距离
    
    // MARK: - State
    @State private var showPhotoPicker = false
    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @StateObject private var selectionManager = SelectedPhotosManager.shared
    @State private var selectionAlbumContext: SelectedAlbumContext? = nil
    
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
    @State private var showAnalysisResult = false  // 显示分析结果页
    @State private var showAnalysisHistory = false  // Phase 3: 历史记录
    @State private var showAnalysisSettings = false  // Phase 5: 分析设置
    @State private var showCollectedTags = false  // Vision 标签库
    @State private var showShareSheet = false  // 导出分享
    @State private var shareURL: URL?  // 分享文件 URL
    private let analysisPipeline = SimpleAnalysisPipeline()
    @State private var hasPrewarmedAnalysis = false
    private let progressThrottler = ProgressThrottler(interval: 0.15)
    
    // 扫描预备弹窗相关
    @State private var showScanPrepareAlert = false  // 扫描预备弹窗
    @State private var showFeelingSheet = false  // 添加感受 Sheet
    @State private var userFeeling: String = ""  // 用户输入的感受
    @State private var showInkCircle = false  // InkCircle 测试页面
    
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
    
    
    // 存储位置信息
    @State private var scannerFrame: CGRect = .zero
    @State private var photoStackFrame: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ZStack {
                    // PhotoScanner - 始终显示在同一位置
                    VStack {
                        Spacer()
                            .frame(height: scannerTopOffset)
                        
                        HStack {
                            Spacer()
                            Button(action: handleImageTap) {
                                loadPhotoScannerImage()
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: imageSize, height: imageSize)
                                    .shadow(
                                        color: scannerShadowColor,
                                        radius: scannerShadowRadius,
                                        x: scannerShadowOffsetX,
                                        y: scannerShadowOffsetY
                                    )
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
                        
                        Spacer()
                    }
                    
                    // 照片模板展示 - 仅在选中照片时显示
                    if selectionManager.hasSelection && !isProcessing && photoStackOpacity > 0 {
                        VStack {
                            Spacer()
                            
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
                                            .onEnded { _ in
                                                handleDragEnd(geometry: geometry)
                                            }
                                    )
                                    .onTapGesture {
                                        showPhotoPicker = true
                                    }
                                Spacer()
                            }
                            .padding(.bottom, photoStackBottomOffset)
                        }
                    }
                    
                    // Phase 3 & 5: 历史记录和设置按钮
                    if !isProcessing {
                        VStack {
                            HStack {
                                Spacer()
                                
                                // InkCircle 测试按钮
                                #if DEBUG
                                Button(action: {
                                    showInkCircle = true
                                }) {
                                    Image(systemName: "circle.grid.3x3.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.primary)
                                        .padding(12)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                .padding(.trailing, 8)
                                #endif
                                
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
                    
                    // 进度条（位于 scanner 下方）
                    if isProcessing {
                        VStack {
                            Spacer()
                                .frame(height: scannerTopOffset + imageSize + progressBarBelowScannerOffset)
                            
                            AnalysisProgressBar(progress: processingProgress, fillColor: .black)
                                .frame(width: progressBarWidth, height: progressBarHeight)
                            
                            Spacer()
                        }
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
                .navigationDestination(isPresented: $showAnalysisResult) {
                    if let result = analysisResult {
                        AnalysisResultView(result: result, onDismiss: {
                            showAnalysisResult = false
                            // 退出分析结果页后清空照片选择
                            selectionManager.clearSelection()
                            selectionAlbumContext = nil
                            // ✅ 标记相册预热需要刷新（用户可能在分析期间拍了新照片）
                            AlbumPreheater.shared.markNeedsRefresh()
                        })
                        .navigationBarBackButtonHidden(false)  // 保留原生返回按钮以支持边缘左滑
                        .toolbar(.hidden, for: .tabBar)
                    }
                }
                .onChange(of: showAnalysisResult) { newValue in
                    // 当从分析结果页返回时（包括系统返回按钮和边缘左滑），清空照片选择
                    if !newValue {
                        selectionManager.clearSelection()
                        selectionAlbumContext = nil
                        AlbumPreheater.shared.markNeedsRefresh()
                    }
                }
                .toolbar(showAnalysisResult ? .hidden : .visible, for: .tabBar)  // 根据状态控制 TabBar 显示
            }
            .fullScreenCover(isPresented: $showPhotoPicker) {
                CustomPhotoPickerView { assets, album in
                    selectionManager.updateSelection(assets)
                    if let album {
                        selectionAlbumContext = SelectedAlbumContext(
                            id: album.collection.localIdentifier,
                            name: album.title
                        )
                    } else {
                        selectionAlbumContext = nil
                    }
                    resetDragState()  // 重新选片后立即恢复照片堆展示状态
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
            // 扫描预备弹窗
            .alert("扫描预备中...", isPresented: $showScanPrepareAlert) {
                Button("添加感受") {
                    // 关闭 alert 并立刻打开输入页
                    showScanPrepareAlert = false
                    showFeelingSheet = true
                    hidePhotoStack()
                }
                Button("确认选片") {
                    // 触感反馈：扫描开始
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    startProcessing()
                }
            }
            // 添加感受 Sheet
            .sheet(isPresented: $showFeelingSheet) {
                FeelingInputSheet(
                    feeling: $userFeeling,
                    onConfirm: {
                        // 触感反馈：扫描开始
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showFeelingSheet = false
                        startProcessing()
                    },
                    onCancel: {
                        showFeelingSheet = false
                        // 恢复照片堆显示并弹回原位
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            photoStackOpacity = 1.0
                            dragOffset = .zero
                        }
                    }
                )
            }
            // InkCircle 测试页面
            .fullScreenCover(isPresented: $showInkCircle) {
                NavigationStack {
                    MetaballDemoView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("关闭") {
                                    showInkCircle = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                prewarmAnalysisStack()
                checkPhotoLibraryStatus()
                
                // ✅ 预热相册数据（后台执行，用户点开相册时会更快）
                Task.detached(priority: .background) {
                    await AlbumPreheater.shared.preheatDefaultAlbum()
                }
                
                // 如果已有选中的照片但图片未加载，重新加载图片
                if !selectionManager.selectedAssets.isEmpty && selectionManager.selectedImages.isEmpty {
                    selectionManager.loadLatestImages()
                }
            }
            .onChange(of: selectionManager.selectedAssets) { _ in
                resetDragState()
                // 当选中照片变化时，确保图片已加载
                if !selectionManager.selectedAssets.isEmpty && selectionManager.selectedImages.isEmpty {
                    selectionManager.loadLatestImages()
                }
            }
        }
    }
    
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
        let photoStackWidth: CGFloat = photoCardBaseSize + 100  // 照片基础尺寸 + 偏移容差
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
            debugLog("✅ Photo stack overlaps with scanner! Showing prepare alert...")
            // 显示扫描预备弹窗
            showScanPrepareAlert = true
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
    
    private func hidePhotoStack() {
        // 让照片堆渐变消失，但不开始分析
        withAnimation(.easeOut(duration: fadeOutDuration)) {
            photoStackOpacity = 0.0
            dragOffset = .zero
        }
    }
    
    private func prewarmAnalysisStack() {
        guard !hasPrewarmedAnalysis else { return }
        hasPrewarmedAnalysis = true
        
        // 在后台线程提前初始化重型依赖，避免首次弹窗/键盘时阻塞主线程
        Task.detached(priority: .utility) {
            _ = ColorNameResolver.shared  // 预加载 2.8 万色名
            _ = CoreDataManager.shared.viewContext  // 启动持久化容器
        }
    }
    
    private func startProcessing() {
        debugLog("=== startProcessing called ===")
        debugLog("Current opacity: \(photoStackOpacity)")
        debugLog("Current isProcessing: \(isProcessing)")
        
        // 如果照片堆还没消失，先让它消失
        if photoStackOpacity > 0 {
            hidePhotoStack()
        }
        
        // 直接开始处理动画
            DispatchQueue.main.async {
                debugLog("Animation started - opacity set to 0, dragOffset reset")
                
                // 延迟后开始显示进度条并开始分析
                DispatchQueue.main.asyncAfter(deadline: .now() + self.fadeOutDuration) {
                    debugLog("Starting analysis")
                    self.isProcessing = true
                    self.startColorAnalysis()
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
            // 获取所有选中的照片
            let assets = selectionManager.selectedAssets
            
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
                withAnimation(.easeInOut(duration: 0.3)) {
                self.processingProgress = 0.01
                }
            }
            
            let throttledHandler: (AnalysisProgress) -> Void = { progress in
                let force = progress.overallProgress >= 0.99
                if self.progressThrottler.shouldEmit(force: force) {
                    Task { @MainActor in
                        self.analysisProgress = progress
                        // 使用动画让进度条平滑过渡
                        withAnimation(.easeInOut(duration: 0.3)) {
                        self.processingProgress = progress.overallProgress
                        }
                    }
                }
            }
            
            // 获取用户输入的感受（在调用分析前获取，确保能保存到 Core Data）
            let userFeelingToPass = self.userFeeling
            
            // 构建相册信息映射（用于显影页的相册归档）
            let albumInfoMap: [String: (identifier: String, name: String)]
            if let albumContext = selectionAlbumContext {
                albumInfoMap = Dictionary(
                    uniqueKeysWithValues: assets.map { asset in
                        (asset.localIdentifier, (identifier: albumContext.id, name: albumContext.name))
                    }
                )
            } else {
                albumInfoMap = [:]
            }
            
            let result = await analysisPipeline.analyzePhotos(
                assets: assets,
                albumInfoMap: albumInfoMap,
                userMessage: userFeelingToPass.isEmpty ? nil : userFeelingToPass,
                progressHandler: throttledHandler
            )
            
            // 先设置 result，但不跳转
            await MainActor.run {
                self.analysisResult = result
            }
            
            // 等待 AI 开始输出内容后再跳转（最多等待 30 秒）
            // 同时逐步更新进度条（从当前进度平滑过渡到 100%）
            let maxWaitTime: TimeInterval = 30.0
            let startWaitTime = Date()
            var hasAIContent = false
            let startProgress = 0.85  // AI 等待阶段起始进度
            let endProgress = 0.99    // AI 等待阶段结束进度
            
            while !hasAIContent && Date().timeIntervalSince(startWaitTime) < maxWaitTime {
                // 检查 AI 是否已开始输出内容
                let aiEvaluation = await MainActor.run { result.aiEvaluation }
                if let evaluation = aiEvaluation {
                    // AI 已开始输出（有内容、有错误、或不再加载中）
                    let hasContent = evaluation.overallEvaluation?.fullText.isEmpty == false
                    let hasError = evaluation.error != nil
                    let notLoading = !evaluation.isLoading
                    
                    if hasContent || hasError || notLoading {
                        hasAIContent = true
                        break
                    }
            }
            
                // 根据等待时间逐步更新进度（平滑过渡）
                let elapsed = Date().timeIntervalSince(startWaitTime)
                let waitProgress = min(elapsed / maxWaitTime, 1.0)
                let currentProgress = startProgress + (endProgress - startProgress) * waitProgress
                
            await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.processingProgress = currentProgress
                    }
                }
                
                // 等待 200ms 后再检查
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            
            // 完成进度
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.processingProgress = 1.0
                }
            }
            
            // 短暂延迟，让进度条显示完成状态
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            // 跳转到结果页
            await MainActor.run {
                self.isProcessing = false
                self.photoStackOpacity = 1.0
                self.dragOffset = .zero
                
                // 清空用户感受（为下次分析准备）
                self.userFeeling = ""
                
                // 触感反馈：进入分析结果页
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // 通知相册 tab 刷新数据
                NotificationCenter.default.post(name: .analysisSessionDidSave, object: nil)
                
                // 使用 NavigationStack 跳转到结果页
                self.showAnalysisResult = true
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
        let count = selectionManager.selectedImages.count
        
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
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoAuthorizationStatus = status
        
        // 预先请求权限，避免首次点击时的长等待
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    photoAuthorizationStatus = newStatus
                }
            }
        }
    }
    
    private func handleImageTap() {
        // 即刻给出触感反馈，避免点击后长时间无响应的感知
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        switch photoAuthorizationStatus {
        case .authorized, .limited:
            // 已授权，直接打开照片选择器
            showPhotoPicker = true
            
        case .notDetermined:
            // 未决定，请求权限
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    photoAuthorizationStatus = status
                    if status == .authorized || status == .limited {
                        showPhotoPicker = true
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
            if let image = selectionManager.selectedImages.first {
                singleCardView(image: image)
            } else {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: photoCardBaseSize, height: photoCardBaseSize)
            }
        }
        #else
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(Color.gray.opacity(0.3))
            .frame(width: photoCardBaseSize, height: photoCardBaseSize)
        #endif
    }
    
    // MARK: - 单张卡片视图辅助函数
    #if canImport(UIKit)
    private func cardDimensions(for image: UIImage) -> (width: CGFloat, height: CGFloat) {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let aspectRatio = imageWidth / imageHeight
        
        // 判断是否为正方形（宽高比在 0.95 到 1.05 之间）
        let isSquare = aspectRatio >= 0.95 && aspectRatio <= 1.05
        
        if imageWidth < imageHeight {
            // 纵向图：固定宽度
            return (photoCardBaseSize, photoCardBaseSize / aspectRatio)
        } else if imageWidth > imageHeight {
            // 横向图：固定高度
            return (photoCardBaseSize * aspectRatio, photoCardBaseSize)
        } else {
            // 正方形：都是 baseSize 的 1.2 倍
            let squareSize = photoCardBaseSize * (isSquare ? 1.2 : 1.0)
            return (squareSize, squareSize)
        }
    }
    
    private func singleCardView(image: UIImage) -> some View {
        let aspectRatio = image.size.width / image.size.height
        let size = cardDimensions(for: image)
        
        return GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                .frame(width: size.width, height: size.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(width: size.width, height: size.height)
    }
    #endif
    
    // MARK: - 两张卡片
    private func doubleCardSection() -> some View {
        #if canImport(UIKit)
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                if i < selectionManager.selectedImages.count {
                    let image = selectionManager.selectedImages[i]
                    let aspectRatio = image.size.width / image.size.height
                    let size = cardDimensions(for: image)
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: size.width, height: size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(middleAngles[i]))
                    .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardBaseSize, height: photoCardBaseSize)
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
                    .frame(width: photoCardBaseSize, height: photoCardBaseSize)
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
                if i < selectionManager.selectedImages.count {
                    let image = selectionManager.selectedImages[i]
                    let aspectRatio = image.size.width / image.size.height
                    let size = cardDimensions(for: image)
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: size.width, height: size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: size.width, height: size.height)
                    .rotationEffect(.degrees(bottomAngles[i]))
                    .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardBaseSize, height: photoCardBaseSize)
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
                    .frame(width: photoCardBaseSize, height: photoCardBaseSize)
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

// MARK: - 添加感受输入 Sheet
struct FeelingInputSheet: View {
    @Binding var feeling: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    private let maxCharacters = 500
    
    private var characterCount: Int {
        feeling.count
    }
    
    private var isOverLimit: Bool {
        characterCount > maxCharacters
    }
    
    private var canConfirm: Bool {
        !isOverLimit
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 输入区域
                VStack(alignment: .leading, spacing: 12) {
                    // 输入框
                    ZStack(alignment: .topLeading) {
                        if feeling.isEmpty {
                            Text("那一刻...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        
                        TextEditor(text: $feeling)
                            .focused($isTextFieldFocused)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                    }
                    .padding(12)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                    .padding(.top, 20)
                    
                    // 字数统计
                    HStack {
                        Spacer()
                        Text("\(characterCount)/\(maxCharacters)")
                            .font(.caption)
                            .foregroundColor(isOverLimit ? .red : .gray)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("添加感受")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认") {
                        onConfirm()
                    }
                    .disabled(!canConfirm)
                    .foregroundColor(canConfirm ? .blue : .gray)
                }
            }
            .onAppear {
                // 立即唤起键盘
                isTextFieldFocused = true
            }
        }
        .interactiveDismissDisabled(false)  // 允许下滑关闭
    }
}

#Preview {
    HomeView()
}
