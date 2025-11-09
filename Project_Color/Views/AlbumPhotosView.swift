//
//  AlbumPhotosView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI
import Photos

struct AlbumPhotosView: View {
    let album: Album
    
    @State private var photos: [PHAsset] = []
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var selectedPhotoIndex: Int? = nil
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 布局常量
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                    PhotoThumbnailView(
                        asset: asset,
                        thumbnail: thumbnails[asset.localIdentifier],
                        isSelected: false
                    )
                    .onTapGesture {
                        selectedPhotoIndex = index
                    }
                    .onAppear {
                        loadThumbnail(for: asset)
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPhotos()
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhotoIndex.map { PhotoViewerItem(index: $0, photos: photos) } },
            set: { selectedPhotoIndex = $0?.index }
        )) { item in
            PhotoDetailView(photos: item.photos, currentIndex: item.index)
        }
    }
    
    // MARK: - 加载照片
    private func loadPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult: PHFetchResult<PHAsset>
        if let collection = album.assetCollection {
            fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        } else {
            // "全部"相册
            fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        }
        
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        photos = assets
    }
    
    // MARK: - 加载缩略图
    private func loadThumbnail(for asset: PHAsset) {
        guard thumbnails[asset.localIdentifier] == nil else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 300, height: 300)
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    thumbnails[asset.localIdentifier] = image
                }
            }
        }
    }
}

// MARK: - 照片缩略图视图
struct PhotoThumbnailView: View {
    let asset: PHAsset
    let thumbnail: UIImage?
    let isSelected: Bool
    
    var body: some View {
        GeometryReader { geometry in
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.width)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - 照片查看器数据模型
struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let index: Int
    let photos: [PHAsset]
}

// MARK: - 照片详情查看
struct PhotoDetailView: View {
    let photos: [PHAsset]
    @State var currentIndex: Int
    @State private var loadedImages: [String: UIImage] = [:]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            // 使用 TabView 实现自然的滑动效果
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, asset in
                    ZoomableImageView(image: loadedImages[asset.localIdentifier])
                        .onAppear {
                            if loadedImages[asset.localIdentifier] == nil {
                                loadImage(for: asset, at: index)
                            }
                        }
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // 顶部关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            // 预加载当前和相邻的图片
            loadImage(for: photos[currentIndex], at: currentIndex)
            if currentIndex > 0 {
                loadImage(for: photos[currentIndex - 1], at: currentIndex - 1)
            }
            if currentIndex < photos.count - 1 {
                loadImage(for: photos[currentIndex + 1], at: currentIndex + 1)
            }
        }
        .onChange(of: currentIndex) { newIndex in
            // 预加载相邻图片
            if newIndex > 0 && loadedImages[photos[newIndex - 1].localIdentifier] == nil {
                loadImage(for: photos[newIndex - 1], at: newIndex - 1)
            }
            if newIndex < photos.count - 1 && loadedImages[photos[newIndex + 1].localIdentifier] == nil {
                loadImage(for: photos[newIndex + 1], at: newIndex + 1)
            }
        }
    }
    
    private func loadImage(for asset: PHAsset, at index: Int) {
        guard loadedImages[asset.localIdentifier] == nil else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 2000, height: 2000)
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    loadedImages[asset.localIdentifier] = image
                }
            }
        }
    }
}

// MARK: - 可缩放的图片视图
struct ZoomableImageView: View {
    let image: UIImage?
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: scale > 1.0 ? 0 : 30)
                                .onChanged { value in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if scale > 1.0 {
                                        lastOffset = offset
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            // 双击切换缩放
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                        .onChange(of: image) { _ in
                            // 切换图片时重置缩放
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            lastScale = 1.0
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview {
    NavigationStack {
        AlbumPhotosView(album: Album(
            id: "preview",
            title: "预览相册",
            assetCollection: nil,
            coverImage: nil,
            photosCount: 10
        ))
    }
}

