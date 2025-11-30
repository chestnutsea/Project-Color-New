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
    var onSelection: ([PHAsset]) -> Void
    
    /// 复用的缓存管理器，用于相册封面和网格缩略图
    private let imageManager = PHCachingImageManager()
    
    // MARK: - 状态
    @State private var albums: [AlbumItem] = []
    @State private var selectedAlbum: AlbumItem?
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
    @State private var lastScrollIndexDuringDrag: Int?
    @State private var keyAssets: [String: PHAsset] = [:]  // albumId -> key asset 缓存
    @State private var albumLoadToken = UUID()  // 防止异步加载错位
    
    // MARK: - 常量
    private let maxSelection = 9
    private let photoSpacing: CGFloat = 1
    private let columns = 3
    
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
            
            // 右侧：确认按钮
            HStack {
                Spacer()
                Button(action: {
                    onSelection(selectedPhotos)
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
    
    // MARK: - 照片网格
    private func photoGrid(photoSize: CGFloat) -> some View {
        GeometryReader { geometry in
            let gridHeight = geometry.size.height
            let trackHeight = gridHeight - scrubberTopMargin - scrubberBottomMargin
            
            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.fixed(photoSize), spacing: photoSpacing), count: columns),
                            spacing: photoSpacing
                        ) {
                            ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                                PhotoCell(
                                    asset: asset,
                                    size: photoSize,
                                    selectionIndex: selectionIndex(for: asset),
                                    onTap: {
                                        toggleSelection(asset)
                                    }
                                )
                                .id(asset.localIdentifier)
                                .onAppear {
                                    // 只在非拖拽状态下更新（避免拖拽时被覆盖）
                                    if !isDraggingScrubber {
                                        updateScrubberFromPhotoIndex(index)
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        scrollViewProxy = proxy
                        // 初始化第一张照片的日期
                        if !photos.isEmpty {
                            updateScrubberFromPhotoIndex(0)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !isDraggingScrubber {
                                    showScrubberTemporarily()
                                }
                            }
                    )
                }
                
                // 日期滚动条
                if showDateScrubber && !photos.isEmpty && !currentDateText.isEmpty {
                    dateScrubberView(trackHeight: trackHeight)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
    }
    
    // MARK: - 更新滚动条位置（从照片索引）
    private func updateScrubberFromPhotoIndex(_ index: Int) {
        guard !photos.isEmpty, index >= 0, index < photos.count else { return }
        
        let newProgress = CGFloat(index) / CGFloat(max(1, photos.count - 1))
        
        // 平滑更新进度
        withAnimation(.easeOut(duration: 0.1)) {
            scrubberProgress = newProgress
        }
        if !isDraggingScrubber {
            lastScrollIndexDuringDrag = nil
        }
        
        // 更新日期文本
        let asset = photos[index]
        currentDateText = formatDate(asset.creationDate)
    }
    
    // MARK: - 临时显示滚动条
    private func showScrubberTemporarily() {
        if !showDateScrubber {
            withAnimation(.easeOut(duration: 0.2)) {
                showDateScrubber = true
            }
        }
        startScrubberHideTimer()
    }
    
    // MARK: - 日期滚动条视图
    private func dateScrubberView(trackHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: scrubberTopMargin + scrubberProgress * trackHeight)
            
            // 日期标签
            Text(currentDateText)
                .font(.system(size: scrubberFontSize, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, scrubberHorizontalPadding)
                .padding(.vertical, scrubberVerticalPadding)
                .background(Color(.systemBackground))
                .cornerRadius(scrubberCornerRadius)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("scrubberTrack"))
                        .onChanged { value in
                            if !isDraggingScrubber {
                                isDraggingScrubber = true
                                cancelScrubberHideTimer()
                            }
                            
                            // 计算新的进度（相对于整个轨道）
                            let dragY = value.location.y
                            let relativeY = dragY - scrubberTopMargin
                            let newProgress = max(0, min(1, relativeY / trackHeight))
                            
                            // 平滑更新进度
                            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                                scrubberProgress = newProgress
                            }
                            
                            // 更新日期文本并滚动到对应位置
                            scrollToProgress(newProgress)
                        }
                        .onEnded { _ in
                            isDraggingScrubber = false
                            startScrubberHideTimer()
                            lastScrollIndexDuringDrag = nil
                        }
                )
            
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .padding(.trailing, scrubberRightPadding)
        .coordinateSpace(name: "scrubberTrack")
    }
    
    // MARK: - 根据进度滚动到对应位置
    private func scrollToProgress(_ progress: CGFloat) {
        guard !photos.isEmpty else { return }
        
        // 计算目标索引
        let targetIndex = Int(round(progress * CGFloat(photos.count - 1)))
        let safeIndex = max(0, min(targetIndex, photos.count - 1))
        
        // 更新日期文本
        let asset = photos[safeIndex]
        currentDateText = formatDate(asset.creationDate)
        
        // 避免重复滚动导致抖动
        if lastScrollIndexDuringDrag == safeIndex {
            return
        }
        lastScrollIndexDuringDrag = safeIndex
        
        // 滚动到目标位置：拖动时关闭动画，抬手后恢复动画
        let targetId = photos[safeIndex].localIdentifier
        if isDraggingScrubber {
            withAnimation(nil) {
                scrollViewProxy?.scrollTo(targetId, anchor: .top)
            }
        } else {
            withAnimation(.easeOut(duration: 0.15)) {
                scrollViewProxy?.scrollTo(targetId, anchor: .top)
            }
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
    private func loadAlbums() {
        isLoading = true
        
        // 检查相册权限
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("📷 相册权限状态: \(status.rawValue)")
        
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                print("📷 权限请求结果: \(newStatus.rawValue)")
                if newStatus == .authorized || newStatus == .limited {
                    self.fetchAlbums()
                } else {
                    DispatchQueue.main.async {
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
                    var item = AlbumItem(
                        id: collection.localIdentifier,
                        collection: collection,
                        title: title,
                        count: assets.count
                    )
                    if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                        foundKeyAssets[item.id] = keyAsset
                        item.thumbnail = self.loadThumbnailInline(for: keyAsset)
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
                        var item = AlbumItem(
                            id: collection.localIdentifier,
                            collection: collection,
                            title: title,
                            count: assets.count
                        )
                        if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                            foundKeyAssets[item.id] = keyAsset
                            item.thumbnail = self.loadThumbnailInline(for: keyAsset)
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
                    var item = AlbumItem(
                        id: collection.localIdentifier,
                        collection: collection,
                        title: title,
                        count: assets.count
                    )
                    if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                        foundKeyAssets[item.id] = keyAsset
                        item.thumbnail = self.loadThumbnailInline(for: keyAsset)
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
                        var item = AlbumItem(
                            id: collection.localIdentifier,
                            collection: collection,
                            title: title,
                            count: assets.count
                        )
                        if let keyAsset = self.latestAsset(in: collection, options: coverOptions) {
                            foundKeyAssets[item.id] = keyAsset
                            item.thumbnail = self.loadThumbnailInline(for: keyAsset)
                        }
                        albumItems.append(item)
                    }
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
            
            // 异步加载封面缩略图，避免阻塞展示（兜底，防止同步加载失败）
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
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var didResume = false
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        Task { @MainActor in
                            if let index = self.albums.firstIndex(where: { $0.id == albumId }) {
                                self.albums[index].thumbnail = image
                            }
                        }
                    }
                    if !didResume {
                        didResume = true
                        continuation.resume()
                    }
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
    
    private func loadPhotos(from album: AlbumItem, token: UUID? = nil) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let loadToken = token ?? albumLoadToken
        
        // 先清空当前照片，避免新旧相册混在一起
        Task { @MainActor in
            self.photos = []
            self.selectedPhotos = []
            self.currentDateText = ""
            self.lastScrollIndexDuringDrag = nil
        }
        
        Task.detached(priority: .userInitiated) {
            let assets = PHAsset.fetchAssets(in: album.collection, options: options)
            var photoArray: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                photoArray.append(asset)
            }
            
            await MainActor.run {
                // 只处理最新一次的加载请求，避免相册错位
                guard loadToken == albumLoadToken else { return }
                print("📷 加载相册 \(album.title) 的照片: \(photoArray.count) 张")
                self.photos = photoArray
                // 切换相册后更新滚动条和日期
                if !photoArray.isEmpty {
                    self.updateScrubberFromPhotoIndex(0)
                } else {
                    self.currentDateText = ""
                }
            }
        }
    }
    
    private func selectAlbum(_ album: AlbumItem) {
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
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: size * 2, height: size * 2),
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
    CustomPhotoPickerView { assets in
        print("Selected \(assets.count) photos")
    }
}
