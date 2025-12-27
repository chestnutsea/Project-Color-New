//
//  AlbumPhotosView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  相册照片网格：显示某个相册内的所有照片
//

import SwiftUI
import CoreData
import Combine

struct AlbumPhotosView: View {
    let album: AlbumInfo
    @StateObject private var viewModel: AlbumPhotosViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoIndex: Int?
    
    init(album: AlbumInfo) {
        self.album = album
        self._viewModel = StateObject(wrappedValue: AlbumPhotosViewModel(albumIdentifier: album.id))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.photos.isEmpty {
                    emptyStateView
                } else {
                    photoGridView
                }
            }
            .navigationTitle(album.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadPhotos()
        }
        .fullScreenCover(item: Binding(
            get: { selectedPhotoIndex.map { PhotoDetailWrapper(index: $0) } },
            set: { selectedPhotoIndex = $0?.index }
        )) { wrapper in
            PhotoDetailView(
                photos: viewModel.photos,
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
            
            Text("暂无照片")
                .font(.title2)
                .foregroundColor(.primary)
            
            Text("该相册中的照片可能已被删除")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 照片网格（紧密排列的正方形，像原生相册）
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
                    ForEach(Array(viewModel.photos.enumerated()), id: \.element.id) { index, photo in
                        PhotoThumbnail(photo: photo, side: width)
                            .frame(width: width, height: width)
                            .onTapGesture {
                                selectedPhotoIndex = index
                            }
                    }
                }
            }
        }
    }
}

// MARK: - 照片缩略图
struct PhotoThumbnail: View {
    let photo: PhotoItem
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
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let thumbnailData = photo.thumbnailData, let image = UIImage(data: thumbnailData) {
            self.thumbnailImage = image
        } else {
            // 保持 placeholder（progress indicator），不请求权限
        }
    }
}

// MARK: - 照片项
struct PhotoItem: Identifiable {
    let id: String  // assetLocalIdentifier
    let assetIdentifier: String
    let visionInfo: PhotoVisionInfo?
    let thumbnailData: Data?  // ✅ 隐私模式：缩略图数据
    let originalImageData: Data?  // ✅ 原图数据（用于大图查看）
}

// MARK: - ViewModel
class AlbumPhotosViewModel: ObservableObject {
    @Published var photos: [PhotoItem] = []
    
    private let albumIdentifier: String
    private let coreDataManager = CoreDataManager.shared
    
    init(albumIdentifier: String) {
        self.albumIdentifier = albumIdentifier
    }
    
    func loadPhotos() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let context = self.coreDataManager.viewContext
            let request = PhotoAnalysisEntity.fetchRequest()
            request.predicate = NSPredicate(format: "albumIdentifier == %@", self.albumIdentifier)
            
            do {
                let entities = try context.fetch(request)
                let decoder = JSONDecoder()
                let sortedEntities = entities.sorted {
                    (self.primarySession(for: $0)?.timestamp ?? Date.distantPast) >
                    (self.primarySession(for: $1)?.timestamp ?? Date.distantPast)
                }
                
                let validPhotos: [PhotoItem] = sortedEntities.compactMap { entity in
                    guard let assetId = entity.assetLocalIdentifier else {
                        return nil
                    }
                    
                    var visionInfo: PhotoVisionInfo?
                    if let data = entity.visionInfo {
                        visionInfo = try? decoder.decode(PhotoVisionInfo.self, from: data)
                    }
                    
                    return PhotoItem(
                        id: assetId,
                        assetIdentifier: assetId,
                        visionInfo: visionInfo,
                        thumbnailData: entity.thumbnailData,
                        originalImageData: entity.originalImageData  // ✅ 加载原图数据
                    )
                }
                
                await MainActor.run {
                    self.photos = validPhotos
                }
                
                print("✅ 加载了 \(validPhotos.count) 张照片（相册: \(self.albumIdentifier)）")
            } catch {
                print("❌ 加载照片失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func primarySession(for photo: PhotoAnalysisEntity) -> AnalysisSessionEntity? {
        // Safely access the session using KVC
        guard let rawValue = photo.value(forKey: "session") else {
            return nil
        }
        
        // Handle direct AnalysisSessionEntity (expected case)
        if let session = rawValue as? AnalysisSessionEntity {
            return session
        }
        
        // Handle NSSet (legacy data model)
        if let sessionSet = rawValue as? NSSet {
            return sessionSet.anyObject() as? AnalysisSessionEntity
        }
        
        // Handle Swift Set (legacy data model)
        if let sessions = rawValue as? Set<AnalysisSessionEntity> {
            return sessions.first
        }
        
        // Log unexpected types
        print("⚠️  Unexpected session type: \(type(of: rawValue))")
        return nil
    }
}

// MARK: - 辅助结构
struct PhotoDetailWrapper: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Preview
#Preview {
    AlbumPhotosView(album: AlbumInfo(
        id: "test-album-id",
        name: "测试相册",
        photoCount: 10,
        coverAssetIdentifier: nil
    ))
}
