//
//  CustomPhotoPickerView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/30.
//  自定义相册选择器：正方形照片网格、相册下拉选择、序号标记
//

import SwiftUI
import Photos
#if canImport(UIKit)
import UIKit
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - 相册信息模型
struct AlbumItem: Identifiable {
    let id: String
    let collection: PHAssetCollection
    let title: String
    let count: Int
    var thumbnail: UIImage?
}

// MARK: - 主视图
struct CustomPhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 选择完成回调，返回选中的 PHAsset 数组
    var onSelection: ([PHAsset], AlbumItem?) -> Void
    
    /// 复用的缓存管理器，用于相册封面和网格缩略图
    private let imageManager = PHCachingImageManager()
    
    // MARK: - 状态
    @State private var albums: [AlbumItem] = []
    @State private var selectedAlbum: AlbumItem?
    @State private var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var photos: [PHAsset] = []
    @State private var selectedPhotos: [PHAsset] = []  // 有序数组，保持选择顺序
    @State private var showAlbumPicker = false
    @State private var isLoading = true
    @State private var showMaxSelectionToast = false  // 最多选择提示
    
    // 日期滚动条相关
    @State private var showDateScrubber = false
    @State private var scrubberProgress: CGFloat = 0  // 0-1，表示在相册中的位置
    @State private var currentDateText: String = ""
    @State private var isDraggingScrubber = false
    @State private var scrubberHideTimer: Timer?
    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var keyAssets: [String: PHAsset] = [:]  // albumId -> key asset 缓存
    @State private var visibleIndices: Set<Int> = []  // 当前可见的所有索引
    @State private var scrubberUpdateWorkItem: DispatchWorkItem?  // 防抖用
    @State private var albumLoadToken = UUID()  // 防止异步加载错位
    @State private var cachedAssets: Set<String> = []  // 已预热的 asset ID（限制最大数量）
    @State private var pendingScrollIndex: Int?
    @State private var desiredLoadedCount: Int = 0  // 需要加载到的目标数量（用于快速拖动）
    
    // ✅ 按需加载相关状态
    @State private var currentFetchResult: PHFetchResult<PHAsset>?  // 当前相册的 fetchResult（懒加载）
    @State private var loadedPhotoCount: Int = 0  // 已加载到内存的照片数量
    @State private var totalPhotoCount: Int = 0  // 相册总照片数（用于滚动条计算）
    @State private var isLoadingMorePhotos: Bool = false  // 是否正在加载更多照片
    
    // MARK: - 常量
    private let maxSelection = 9
    private let photoSpacing: CGFloat = 1
    private let columns = 3
    private let thumbnailSize = CGSize(width: 200, height: 200)  // 缩略图尺寸
    private let preheatBatchSize = 50  // 每批预热数量
    private let loadBatchSize = 80  // 每批加载数量（用于快速滚动时补齐数据）
    private let scrubberLoadAhead = 90  // 拖动滚动条时，额外预加载的照片数量
    
    // 日期滚动条布局常量
    private let scrubberRightPadding: CGFloat = 5
    private let scrubberCornerRadius: CGFloat = 8
    private let scrubberHorizontalPadding: CGFloat = 12
    private let scrubberVerticalPadding: CGFloat = 6
    private let scrubberFontSize: CGFloat = 13
    private let scrubberTopMargin: CGFloat = 20
    private let scrubberBottomMargin: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            let photoSize = (geometry.size.width - CGFloat(columns - 1) * photoSpacing) / CGFloat(columns)
            
            ZStack {
                // 背景色
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部导航栏
                    navigationBar
                    
                    // 照片网格
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if photos.isEmpty {
                        emptyStateView
                    } else {
                        photoGrid(photoSize: photoSize)
                    }
                }
                
                // 相册选择下拉框
                if showAlbumPicker {
                    albumPickerOverlay(geometry: geometry)
                }
                
                // 最多选择提示 Toast
                if showMaxSelectionToast {
                    VStack {
                        Spacer()
                        Text("最多选择 9 张照片")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
        }
        .onAppear {
            loadAlbums()
        }
    }
    
    // MARK: - 导航栏
    private var navigationBar: some View {
        ZStack {
            // 中间：相册选择器
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showAlbumPicker.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Text(selectedAlbum?.title ?? "最近项目")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Image(systemName: showAlbumPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            
            // 左侧：关闭按钮
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            
            // 右侧：已选数量 + 确认按钮
            HStack(spacing: 8) {
                Spacer()
                
                // 显示已选数量（跨相册总数）
                if !selectedPhotos.isEmpty {
                    Text("\(selectedPhotos.count)/\(maxSelection)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    onSelection(selectedPhotos, selectedAlbum)
                    dismiss()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(selectedPhotos.isEmpty ? .gray : .primary)
                        .frame(width: 44, height: 44)
                }
                .disabled(selectedPhotos.isEmpty)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 46, weight: .regular))
                .foregroundColor(.secondary)
            
            Text("没有可显示的照片")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 6) {
                Text("请检查相册权限，或稍后再试。")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if authorizationStatus == .limited {
                    Text("当前为“部分照片”，需要添加可访问的照片。")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            
            HStack(spacing: 12) {
                Button(action: reloadAlbums) {
                    Text("刷新相册")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                }
                
                if authorizationStatus == .limited {
                    Button(action: manageLimitedLibrary) {
                        Text("管理可访问照片")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 照片网格
    private func photoGrid(photoSize: CGFloat) -> some View {
        GeometryReader { geometry in
            let gridHeight = geometry.size.height
            let trackHeight = gridHeight - scrubberTopMargin - scrubberBottomMargin

            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.fixed(photoSize), spacing: photoSpacing),
                                count: columns
                            ),
                            spacing: photoSpacing
                        ) {
                            ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                                PhotoCell(
                                    asset: asset,
                                    size: photoSize,
                                    selectionIndex: selectionIndex(for: asset),
                                    imageManager: imageManager
                                ) {
                                    toggleSelection(asset)
                                }
                                .id(asset.localIdentifier)
                                .onAppear {
                                    handleCellAppear(index: index)
                                }
                                .onDisappear {
                                    handleCellDisappear(index: index)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollViewProxy = proxy
                    }
                }

                if showDateScrubber && !currentDateText.isEmpty {
                    dateScrubberView(trackHeight: trackHeight)
                }
            }
        }
    }
    
    // MARK: - Cell 出现时的处理
    private func handleCellAppear(index: Int) {
        // 加载更多照片
        loadMorePhotosIfNeeded(currentIndex: index)
        
        // 记录可见索引
        visibleIndices.insert(index)
        
        // 如果正在拖动日期选择器，不更新
        guard !isDraggingScrubber else { return }
        
        // 防抖更新日期选择器
        scheduleScrubberUpdate()
    }
    
    // MARK: - Cell 消失时的处理
    private func handleCellDisappear(index: Int) {
        visibleIndices.remove(index)
    }
    
    // MARK: - 防抖更新日期选择器（等待滚动稳定后更新）
    private func scheduleScrubberUpdate() {
        // 取消之前的更新任务
        scrubberUpdateWorkItem?.cancel()
        
        // 创建新的延迟更新任务（防抖 100ms）
        let workItem = DispatchWorkItem { [self] in
            updateScrubberFromVisibleIndices()
        }
        scrubberUpdateWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
    
    // MARK: - 根据可见索引更新日期选择器
    private func updateScrubberFromVisibleIndices() {
        guard !isDraggingScrubber else { return }
        guard !visibleIndices.isEmpty else { return }
        
        // 使用可见索引中最小的（即屏幕顶部的照片）
        let topIndex = visibleIndices.min() ?? 0
        
        guard topIndex >= 0, topIndex < photos.count else { return }
        
        let total = max(1, totalPhotoCount > 0 ? totalPhotoCount : photos.count)
        let newProgress = CGFloat(topIndex) / CGFloat(max(1, total - 1))
        
        // 直接更新，不使用动画
        scrubberProgress = newProgress
        currentDateText = formatDate(photos[topIndex].creationDate)
        
        // 显示日期选择器
        if !showDateScrubber {
            showDateScrubber = true
        }
        startScrubberHideTimer()
    }

    
    // MARK: - 临时显示滚动条
    private func showScrubberTemporarily() {
        if !showDateScrubber {
            showDateScrubber = true
        }
        startScrubberHideTimer()
    }
    
    // MARK: - 日期滚动条视图
    private func dateScrubberView(trackHeight: CGFloat) -> some View {
        // 计算日期标签的垂直位置
        let labelY = scrubberTopMargin + scrubberProgress * trackHeight
        
        return VStack(spacing: 0) {
            Spacer()
                .frame(height: labelY)
            
            // 日期标签
            Text(currentDateText)
                .font(.system(size: scrubberFontSize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, scrubberHorizontalPadding)
                .padding(.vertical, scrubberVerticalPadding)
                .background(Color(.systemBackground))
                .cornerRadius(scrubberCornerRadius)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.trailing, scrubberRightPadding)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleScrubberDrag(value: value, trackHeight: trackHeight)
                }
                .onEnded { _ in
                    isDraggingScrubber = false
                    startScrubberHideTimer()
                }
        )
    }
    
    // MARK: - 处理日期选择器拖动
    private func handleScrubberDrag(value: DragGesture.Value, trackHeight: CGFloat) {
        isDraggingScrubber = true
        cancelScrubberHideTimer()
        
        // 计算新的进度
        let dragY = value.location.y
        let relativeY = dragY - scrubberTopMargin
        let newProgress = max(0, min(1, relativeY / trackHeight))
        
        // 更新进度
        scrubberProgress = newProgress
        
        // 计算目标索引
        let total = max(1, totalPhotoCount)
        let targetIndex = Int(newProgress * CGFloat(total - 1))
        
        // 预加载数据
        if let fetchResult = currentFetchResult {
            queueLoadIfNeeded(upTo: targetIndex + scrubberLoadAhead, fetchResult: fetchResult)
        }
        
        // 滚动到目标位置
        let clampedIndex = min(max(0, targetIndex), photos.count - 1)
        if clampedIndex >= 0 && clampedIndex < photos.count {
            let asset = photos[clampedIndex]
            currentDateText = formatDate(asset.creationDate)
            
            // 使用无动画滚动，确保跟手
            scrollViewProxy?.scrollTo(asset.localIdentifier, anchor: .top)
        }
    }
    
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        // 自动使用系统语言
        formatter.locale = Locale.current
        
        return formatter.string(from: date)
    }
    
    private func startScrubberHideTimer() {
        cancelScrubberHideTimer()
        scrubberHideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                showDateScrubber = false
            }
        }
    }
    
    private func cancelScrubberHideTimer() {
        scrubberHideTimer?.invalidate()
        scrubberHideTimer = nil
    }
    
    // MARK: - 相册选择下拉框
    private func albumPickerOverlay(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAlbumPicker = false
                    }
                }
            
            // 相册列表
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(albums) { album in
                            AlbumRow(album: album, isSelected: selectedAlbum?.id == album.id)
                                .onTapGesture {
                                    selectAlbum(album)
                                }
                            
                            if album.id != albums.last?.id {
                                Divider()
                                    .padding(.leading, 80)
                            }
                        }
                    }
                }
                .frame(height: geometry.size.height / 2)
                .background(Color(.systemBackground))
            }
            .offset(y: 44)  // 导航栏高度
        }
    }
    
    // MARK: - 数据加载
    private func reloadAlbums() {
        // 重新加载相册与照片，清空旧状态避免空白
        stopPreheatThumbnails()
        albumLoadToken = UUID()
        albums = []
        photos = []
        selectedAlbum = nil
        isLoading = true
        loadAlbums()
    }
    
    private func manageLimitedLibrary() {
        #if canImport(UIKit)
        guard let rootVC = keyWindowRootViewController() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootVC)
        // 等待系统弹窗操作后刷新数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.reloadAlbums()
        }
        #endif
    }
    
    private func loadAlbums() {
        isLoading = true
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // 检查相册权限
        let status = authorizationStatus
        print("📷 相册权限状态: \(status.rawValue)")
        
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                print("📷 权限请求结果: \(newStatus.rawValue)")
                DispatchQueue.main.async {
                    self.authorizationStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.fetchAlbums()
                    } else {
                        self.isLoading = false
                    }
                }
            }
        } else if status == .authorized || status == .limited {
            fetchAlbums()
        } else {
            isLoading = false
        }
    }
    
    #if canImport(UIKit)
    private func keyWindowRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
    #endif
    
    private func fetchAlbums() {
        Task.detached(priority: .userInitiated) {
            var albumItems: [AlbumItem] = []
            var addedIds = Set<String>()  // 避免重复添加
            var foundKeyAssets: [String: PHAsset] = [:]
            
            // 封面用的最新照片（仅 1 张）
            let coverOptions = PHFetchOptions()
            coverOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            coverOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            coverOptions.fetchLimit = 1
            
            // 统计数量/加载列表用的全部照片
            let countOptions = PHFetchOptions()
            countOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            countOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            
            // 1. 最近项目 / 所有照片（smartAlbumUserLibrary）
            let recentAlbums = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .smartAlbumUserLibrary,
                options: nil
            )
            
            print("📷 smartAlbumUserLibrary 数量: \(recentAlbums.count)")
            
            recentAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
                let title = self.localizedAlbumTitle(collection)
                print("📷 \(title): \(assets.count) 张照片")
                if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                    addedIds.insert(collection.localIdentifier)
                    let item = AlbumItem(
                        id: collection.localIdentifier,
                        collection: collection,
                        title: title,
                        count: assets.count
                    )
                    if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                        foundKeyAssets[item.id] = keyAsset
                        // ✅ 移除同步加载，改为异步加载
                    }
                    albumItems.append(item)
                }
            }
            
            // 2. 最近添加（smartAlbumRecentlyAdded）- 如果上面没有照片，用这个作为备选
            if albumItems.isEmpty {
                let recentlyAdded = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .smartAlbumRecentlyAdded,
                    options: nil
                )
                
                print("📷 smartAlbumRecentlyAdded 数量: \(recentlyAdded.count)")
                
                recentlyAdded.enumerateObjects { collection, _, _ in
                    let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
                    let title = self.localizedAlbumTitle(collection)
                    print("📷 \(title): \(assets.count) 张照片")
                    if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                        addedIds.insert(collection.localIdentifier)
                        let item = AlbumItem(
                            id: collection.localIdentifier,
                            collection: collection,
                            title: title,
                            count: assets.count
                        )
                        if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                            foundKeyAssets[item.id] = keyAsset
                            // ✅ 移除同步加载，改为异步加载
                        }
                        albumItems.append(item)
                    }
                }
            }
            
            // 3. 用户相册（只包含用户手动添加的照片，这是 iOS 的正常行为）
            // 注意：同一张照片可能出现在多个相册中，这是正常的
            let userAlbums = PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,  // 只获取用户创建的普通相册，排除同步相册等
                options: nil
            )
            
            print("📷 用户相册数量: \(userAlbums.count)")
            
            userAlbums.enumerateObjects { collection, _, _ in
                let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
                if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                    addedIds.insert(collection.localIdentifier)
                    // 用户相册使用 localizedTitle，如果为空则使用"未命名相册"
                    let title = collection.localizedTitle ?? "未命名相册"
                    let item = AlbumItem(
                        id: collection.localIdentifier,
                        collection: collection,
                        title: title,
                        count: assets.count
                    )
                    if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                        foundKeyAssets[item.id] = keyAsset
                        // ✅ 移除同步加载，改为异步加载
                    }
                    albumItems.append(item)
                }
            }
            
            // 4. 其他智能相册（收藏、截屏等）
            let otherSmartTypes: [PHAssetCollectionSubtype] = [
                .smartAlbumFavorites,
                .smartAlbumScreenshots,
                .smartAlbumSelfPortraits,
                .smartAlbumPanoramas
            ]
            
            for subtype in otherSmartTypes {
                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: subtype,
                    options: nil
                )
                
                collections.enumerateObjects { collection, _, _ in
                    let assets = PHAsset.fetchAssets(in: collection, options: countOptions)
                    if assets.count > 0 && !addedIds.contains(collection.localIdentifier) {
                        addedIds.insert(collection.localIdentifier)
                        let title = self.localizedAlbumTitle(collection)
                        let item = AlbumItem(
                            id: collection.localIdentifier,
                            collection: collection,
                            title: title,
                            count: assets.count
                        )
                        if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                            foundKeyAssets[item.id] = keyAsset
                            // ✅ 移除同步加载，改为异步加载
                        }
                        albumItems.append(item)
                    }
                }
            }
            
            // 如果没有任何相册，尝试直接获取所有照片作为兜底
            if albumItems.isEmpty {
                let allAssets = PHAsset.fetchAssets(with: countOptions)
                print("📷 兜底直接获取所有照片: \(allAssets.count) 张")
                
                if allAssets.count > 0 {
                    var allAssetsArray: [PHAsset] = []
                    allAssetsArray.reserveCapacity(allAssets.count)
                    allAssets.enumerateObjects { asset, _, _ in
                        allAssetsArray.append(asset)
                    }
                    
                    let title = localizedAllPhotosTitle()
                    let transient = PHAssetCollection.transientAssetCollection(
                        with: allAssetsArray,
                        title: title
                    )
                    let fallbackAlbum = AlbumItem(
                        id: transient.localIdentifier,
                        collection: transient,
                        title: title,
                        count: allAssets.count
                    )
                    if let firstAsset = allAssets.firstObject {
                        foundKeyAssets[fallbackAlbum.id] = firstAsset
                    }
                    albumItems.append(fallbackAlbum)
                }
            }
            
            print("📷 总共加载了 \(albumItems.count) 个相册")
            
            await MainActor.run {
                self.albums = albumItems
                self.keyAssets = foundKeyAssets
                // 默认选择第一个相册（最近项目）
                if let firstAlbum = albumItems.first {
                    albumLoadToken = UUID()
                    self.selectedAlbum = firstAlbum
                    self.loadPhotos(from: firstAlbum, token: albumLoadToken)
                    print("📷 默认选中相册: \(firstAlbum.title), 照片数: \(firstAlbum.count)")
                } else {
                    print("📷 没有找到任何相册")
                }
                self.isLoading = false
            }
            
            // ✅ 优化：异步加载封面缩略图，先显示列表再加载图片
            await withTaskGroup(of: Void.self) { group in
                for (albumId, asset) in foundKeyAssets {
                    group.addTask {
                        await self.loadThumbnailAsync(for: asset, albumId: albumId)
                    }
                }
            }
        }
    }
    
    private func loadThumbnailAsync(for asset: PHAsset, albumId: String) async {
        let assetId = asset.localIdentifier
        
        // ✅ 优化：先检查缓存，如果命中就直接使用
        if let cachedImage = ThumbnailCache.shared.image(for: assetId) {
            await MainActor.run {
                if let index = self.albums.firstIndex(where: { $0.id == albumId }) {
                    self.albums[index].thumbnail = cachedImage
                }
            }
            return
        }
        
        // 缓存未命中，才加载图片
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat  // ✅ 使用 highQualityFormat 确保只回调一次
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        // ✅ 修复：防止重复 resume 导致闪退
        let loadedImage: UIImage? = await withCheckedContinuation { continuation in
            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
        
        if let image = loadedImage {
            // ✅ 存入缓存，下次直接使用
            ThumbnailCache.shared.setImage(image, for: assetId)
            await MainActor.run {
                if let index = self.albums.firstIndex(where: { $0.id == albumId }) {
                    self.albums[index].thumbnail = image
                }
            }
        }
    }
    
    private func loadThumbnailInline(for asset: PHAsset) -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        
        var result: UIImage?
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            result = image
        }
        return result
    }
    
    /// 获取优先使用的相册封面资源（Key Asset 优先，其次首张照片）
    private func keyAsset(for collection: PHAssetCollection, assets: PHFetchResult<PHAsset>) -> PHAsset? {
        let keyAssets = PHAsset.fetchKeyAssets(in: collection, options: nil)
        return keyAssets?.firstObject ?? assets.firstObject
    }
    
    /// 获取相册最新一张照片（封面使用）
    private func latestAsset(in collection: PHAssetCollection, options: PHFetchOptions? = nil) -> PHAsset? {
        let opts = options ?? {
            let o = PHFetchOptions()
            o.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            o.fetchLimit = 1
            return o
        }()
        return PHAsset.fetchAssets(in: collection, options: opts).firstObject
    }
    
    /// 获取相册的本地化名称
    private func localizedAlbumTitle(_ collection: PHAssetCollection) -> String {
        let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        
        // 如果用户系统语言是中文，优先使用手动映射（因为 localizedTitle 可能返回英文）
        if prefersChinese {
            switch collection.assetCollectionSubtype {
            case .smartAlbumUserLibrary: return "所有照片"
            case .smartAlbumRecentlyAdded: return "最近项目"
            case .smartAlbumFavorites: return "个人收藏"
            case .smartAlbumScreenshots: return "截屏"
            case .smartAlbumSelfPortraits: return "自拍"
            case .smartAlbumPanoramas: return "全景照片"
            case .smartAlbumVideos: return "视频"
            case .smartAlbumLivePhotos: return "实况照片"
            case .smartAlbumDepthEffect: return "人像"
            case .smartAlbumBursts: return "连拍快照"
            case .smartAlbumTimelapses: return "延时摄影"
            case .smartAlbumSlomoVideos: return "慢动作"
            default: break
            }
        }
        
        // 非中文系统或用户自建相册，使用系统返回的名称
        return collection.localizedTitle ?? (prefersChinese ? "相册" : "Album")
    }
    
    private func localizedAllPhotosTitle() -> String {
        let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        return prefersChinese ? "所有照片" : "All Photos"
    }
    
    private func loadPhotos(from album: AlbumItem, token: UUID? = nil) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let loadToken = token ?? albumLoadToken
        
        // 先清空当前照片，避免新旧相册混在一起
        // 注意：不清空 selectedPhotos，保留跨相册的选择
        Task { @MainActor in
            self.photos = []
            // self.selectedPhotos = []  // ✅ 移除：保留跨相册选择
            self.currentDateText = ""
            self.pendingScrollIndex = nil
            self.desiredLoadedCount = 0
        }
        
        Task.detached(priority: .userInitiated) {
            let fetchResult = PHAsset.fetchAssets(in: album.collection, options: options)
            let totalCount = fetchResult.count
            
            // ✅ 内存优化：只加载前 50 张到内存，其余按需加载
            // PHFetchResult 本身是懒加载的，不会占用大量内存
            let initialLoadCount = min(50, totalCount)
            
            let initialPhotos = await withCheckedContinuation { continuation in
                var photos: [PHAsset] = []
                photos.reserveCapacity(initialLoadCount)
                fetchResult.enumerateObjects { asset, index, stop in
                    if index < initialLoadCount {
                        photos.append(asset)
                    } else {
                        stop.pointee = true
                    }
                }
                continuation.resume(returning: photos)
            }
            
            await MainActor.run {
                guard loadToken == albumLoadToken else { return }
                print("📷 加载相册 \(album.title) 的照片: \(initialPhotos.count)/\(totalCount) 张（初始加载）")
                self.photos = initialPhotos
                self.totalPhotoCount = totalCount  // ✅ 保存总数用于滚动条
                self.desiredLoadedCount = initialPhotos.count
                
                if !initialPhotos.isEmpty {
                    // 初始化日期选择器状态
                    self.visibleIndices = [0]
                    self.scrubberProgress = 0
                    self.currentDateText = self.formatDate(initialPhotos[0].creationDate)
                    self.showDateScrubber = true
                    // ✅ 只预热前 50 张缩略图，不预热全部
                    self.startPreheatThumbnails(for: initialPhotos)
                } else {
                    self.currentDateText = ""
                }
                
                // ✅ 存储 fetchResult 用于按需加载更多照片
                self.currentFetchResult = fetchResult
                self.loadedPhotoCount = initialPhotos.count
            }
        }
    }
    
    /// 按需加载更多照片（当用户滚动到底部时调用）
    private func loadMorePhotosIfNeeded(currentIndex: Int) {
        guard let fetchResult = currentFetchResult else { return }
        
        let threshold = max(0, loadedPhotoCount - 20)  // 提前 20 张开始加载
        guard currentIndex >= threshold else { return }
        
        // 让加载目标稍微超前，避免滚动到终点才加载
        let targetCount = currentIndex + loadBatchSize
        queueLoadIfNeeded(upTo: targetCount, fetchResult: fetchResult)
    }
    
    private func queueLoadIfNeeded(upTo requiredCount: Int, fetchResult: PHFetchResult<PHAsset>) {
        let totalCount = fetchResult.count
        let clampedCount = min(totalCount, requiredCount)
        guard clampedCount > loadedPhotoCount else {
            // 数据已足够，尝试完成待滚动
            attemptScrollToPendingIndex()
            return
        }
        
        desiredLoadedCount = max(desiredLoadedCount, clampedCount)
        startLoadingIfNeeded(fetchResult: fetchResult)
    }
    
    private func startLoadingIfNeeded(fetchResult: PHFetchResult<PHAsset>) {
        guard !isLoadingMorePhotos else { return }
        
        let startIndex = loadedPhotoCount
        let endIndex = min(desiredLoadedCount, fetchResult.count)
        guard startIndex < endIndex else { return }
        
        isLoadingMorePhotos = true
        let currentToken = albumLoadToken
        let rangeEnd = min(endIndex, startIndex + loadBatchSize)
        let loadRange = startIndex..<rangeEnd
        
        Task.detached(priority: .userInitiated) {
            let loadedPhotos = await fetchAssets(from: fetchResult, range: loadRange)
            
            await MainActor.run {
                guard currentToken == self.albumLoadToken else {
                    self.isLoadingMorePhotos = false
                    return
                }
                
                self.photos.append(contentsOf: loadedPhotos)
                self.loadedPhotoCount = self.photos.count
                self.isLoadingMorePhotos = false
                
                print("📷 按需加载更多照片: \(self.loadedPhotoCount)/\(fetchResult.count) 张")
                
                self.startPreheatThumbnails(for: loadedPhotos)
                self.attemptScrollToPendingIndex()
                
                // 如果还有目标未满足，继续加载下一批
                if self.loadedPhotoCount < self.desiredLoadedCount {
                    self.startLoadingIfNeeded(fetchResult: fetchResult)
                }
            }
        }
    }
    
    private func fetchAssets(from fetchResult: PHFetchResult<PHAsset>, range: Range<Int>) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            var assets: [PHAsset] = []
            assets.reserveCapacity(range.count)
            fetchResult.enumerateObjects(at: IndexSet(integersIn: range), options: []) { asset, _, _ in
                assets.append(asset)
            }
            continuation.resume(returning: assets)
        }
    }
    
    private func attemptScrollToPendingIndex() {
        guard let targetIndex = pendingScrollIndex else { return }
        guard targetIndex < photos.count else { return }
        
        pendingScrollIndex = nil
        
        // 滚动到目标位置
        let asset = photos[targetIndex]
        currentDateText = formatDate(asset.creationDate)
        scrollViewProxy?.scrollTo(asset.localIdentifier, anchor: .top)
    }
    
    // MARK: - PHCachingImageManager 预热
    
    /// ✅ 内存优化：限制预热缓存的最大数量
    private let maxCachedAssetCount = 100
    
    /// 使用 PHCachingImageManager 预热缩略图（限制数量，避免内存暴涨）
    private func startPreheatThumbnails(for assets: [PHAsset]) {
        // 过滤出未预热的 assets
        let uncachedAssets = assets.filter { !cachedAssets.contains($0.localIdentifier) }
        guard !uncachedAssets.isEmpty else { return }
        
        // ✅ 限制预热数量，避免内存暴涨
        let assetsToCache = Array(uncachedAssets.prefix(preheatBatchSize))
        
        print("🔥 预热 \(assetsToCache.count) 张缩略图（限制最大 \(preheatBatchSize) 张）")
        
        // 使用 PHCachingImageManager 的原生预热 API
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        imageManager.startCachingImages(
            for: assetsToCache,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
        
        // 记录已预热的 assets
        for asset in assetsToCache {
            cachedAssets.insert(asset.localIdentifier)
        }
        
        // ✅ 如果缓存的 ID 过多，清理旧的
        if cachedAssets.count > maxCachedAssetCount {
            // 清理超出的部分（保留最近添加的）
            let overflow = cachedAssets.count - maxCachedAssetCount
            let idsToRemove = Array(cachedAssets.prefix(overflow))
            for id in idsToRemove {
                cachedAssets.remove(id)
            }
            print("🧹 清理缓存 ID: 移除 \(overflow) 个旧 ID")
        }
    }
    
    /// 停止预热（切换相册时调用）
    private func stopPreheatThumbnails() {
        imageManager.stopCachingImagesForAllAssets()
        cachedAssets.removeAll()
        currentFetchResult = nil
        loadedPhotoCount = 0
        totalPhotoCount = 0
        print("🛑 停止缩略图预热，清理状态")
    }
    
    private func selectAlbum(_ album: AlbumItem) {
        // 切换相册时停止之前的预热
        stopPreheatThumbnails()
        selectedAlbum = album
        albumLoadToken = UUID()
        loadPhotos(from: album, token: albumLoadToken)
        withAnimation(.easeInOut(duration: 0.25)) {
            showAlbumPicker = false
        }
    }
    
    private func selectionIndex(for asset: PHAsset) -> Int? {
        selectedPhotos.firstIndex { $0.localIdentifier == asset.localIdentifier }.map { $0 + 1 }
    }
    
    private func toggleSelection(_ asset: PHAsset) {
        if let index = selectedPhotos.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
            // 已选中，移除
            selectedPhotos.remove(at: index)
        } else {
            // 未选中，添加（如果未达上限）
            if selectedPhotos.count < maxSelection {
                selectedPhotos.append(asset)
            } else {
                // 已达上限，显示提示
                showMaxSelectionToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        showMaxSelectionToast = false
                    }
                }
            }
        }
    }
}

// MARK: - 照片单元格
struct PhotoCell: View {
    let asset: PHAsset
    let size: CGFloat
    let selectionIndex: Int?  // nil 表示未选中，1-9 表示选中序号
    let imageManager: PHCachingImageManager  // ✅ 使用预热的缓存管理器
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var lastAssetId: String = ""
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 照片
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: size, height: size)
            .clipped()
            
            // 选中遮罩
            if selectionIndex != nil {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: size, height: size)
            }
            
            // 序号标记（仅选中时显示）
            if let index = selectionIndex {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Text("\(index)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            prepareForAssetChangeIfNeeded()
            loadImage()
        }
        .onChange(of: asset.localIdentifier) { _ in
            prepareForAssetChangeIfNeeded()
            loadImage()
        }
    }
    
    private func prepareForAssetChangeIfNeeded() {
        if lastAssetId != asset.localIdentifier {
            image = nil
            lastAssetId = asset.localIdentifier
        }
    }
    
    private func loadImage() {
        let assetId = asset.localIdentifier
        let targetSize = CGSize(width: size * 2, height: size * 2)
        
        // ✅ 优化：先检查缓存（即使尺寸不同，也可以先显示缓存图片，然后异步加载精确尺寸）
        if let cachedImage = ThumbnailCache.shared.image(for: assetId) {
            // 如果缓存图片尺寸足够大，直接使用
            if cachedImage.size.width >= targetSize.width && cachedImage.size.height >= targetSize.height {
                self.image = cachedImage
                return
            }
            // 否则先显示缓存图片，然后加载精确尺寸
            self.image = cachedImage
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        // ✅ 使用预热的 PHCachingImageManager，命中预热缓存
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                self.image = image
            }
        }
    }
}

// MARK: - 相册行
struct AlbumRow: View {
    let album: AlbumItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            Group {
                if let thumbnail = album.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .cornerRadius(4)
            
            // 相册信息
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                
                Text("\(album.count)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 选中标记
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}



#Preview {
    CustomPhotoPickerView { assets, _ in
        print("Selected \(assets.count) photos")
    }
}
