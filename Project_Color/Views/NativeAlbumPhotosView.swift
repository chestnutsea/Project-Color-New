//
//  NativeAlbumPhotosView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  原生相册照片网格：显示系统相册中的所有照片（用于查看和选择）
//

import SwiftUI
import Photos

struct NativeAlbumPhotosView: View {
    let album: Album  // 来自 AlbumViewModel 的 Album 类型
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [PHAsset] = []
    @State private var selectedPhotoIndex: Int?
    
    var body: some View {
        Group {
            if photos.isEmpty {
                emptyStateView
            } else {
                photoGridView
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPhotos()
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhotoIndex.map { NativePhotoDetailWrapper(index: $0) } },
            set: { selectedPhotoIndex = $0?.index }
        )) { wrapper in
            NativePhotoDetailView(
                photos: photos,
                initialIndex: wrapper.index,
                onDismiss: { selectedPhotoIndex = nil }
            )
        }
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("相册为空")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .padding(40)
    }
    
    // MARK: - 照片网格（紧密排列，像原生相册）
    private var photoGridView: some View {
        GeometryReader { geometry in
            let columns = 3
            let spacing: CGFloat = 1
            let totalSpacing = spacing * CGFloat(columns - 1)
            let width = floor((geometry.size.width - totalSpacing) / CGFloat(columns))
            
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                        NativePhotoThumbnail(asset: asset, side: width)
                            .frame(width: width, height: width)
                            .onTapGesture {
                                selectedPhotoIndex = index
                            }
                    }
                }
            }
        }
    }
    
    private func loadPhotos() {
        guard let collection = album.assetCollection else { return }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        var assets: [PHAsset] = []
        
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        self.photos = assets
    }
}

// MARK: - 原生照片缩略图
struct NativePhotoThumbnail: View {
    let asset: PHAsset
    let side: CGFloat
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
        }
    }
}

// MARK: - 原生照片详情视图
struct NativePhotoDetailView: View {
    let photos: [PHAsset]
    let initialIndex: Int
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int
    
    init(photos: [PHAsset], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var currentAsset: PHAsset {
        photos[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) / \(photos.count)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                }
                .background(Color.black.opacity(0.3))
                
                // 照片轮播
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                        NativePhotoImageView(asset: asset)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .statusBar(hidden: true)
    }
}

// MARK: - 原生照片图像视图
struct NativePhotoImageView: View {
    let asset: PHAsset
    @State private var fullImage: UIImage?
    @State private var isLoading: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.6))
                        Text("加载失败")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    private func loadFullImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .none
        
        let targetSize = CGSize(
            width: UIScreen.main.bounds.width * UIScreen.main.scale,
            height: UIScreen.main.bounds.height * UIScreen.main.scale
        )
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                if let image = image {
                    self.fullImage = image
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - 辅助结构
struct NativePhotoDetailWrapper: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Preview
#Preview {
    NavigationStack {
        Text("Native Album Photos View")
    }
}
