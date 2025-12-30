//
//  PhotoDetailView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  照片详情页：支持左右滑动和上滑显示标签
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let photos: [PhotoItem]
    let initialIndex: Int
    let onDismiss: () -> Void
    
    @State private var currentIndex: Int
    @State private var isTagsExpanded: Bool = false
    @GestureState private var dragOffset: CGFloat = 0
    
    init(photos: [PhotoItem], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var currentPhoto: PhotoItem {
        photos[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部工具栏
                topBar
                
                // 照片区域
                photoCarousel
                
                // 标签区域
                tagsSection
            }
        }
        .statusBar(hidden: true)
    }
    
    // MARK: - 顶部工具栏
    private var topBar: some View {
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
    }
    
    // MARK: - 照片轮播
    private var photoCarousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                PhotoImageView(photo: photo)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 上滑手势：展开标签
                    if value.translation.height < -50 && !isTagsExpanded {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isTagsExpanded = true
                        }
                    }
                    // 下滑手势：收起标签
                    else if value.translation.height > 50 && isTagsExpanded {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isTagsExpanded = false
                        }
                    }
                }
        )
    }
    
    // MARK: - 标签区域
    private var tagsSection: some View {
        VStack(spacing: 0) {
            // 拖动指示器
            if !isTagsExpanded {
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
            
            // 标签内容
            if let visionInfo = currentPhoto.visionInfo {
                TagsContentView(visionInfo: visionInfo, isExpanded: isTagsExpanded)
            } else {
                Text("无标签信息")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isTagsExpanded ? UIScreen.main.bounds.height * 0.6 : 300)  // 增加 100 高度：80 -> 180
        .background(
            RoundedRectangle(cornerRadius: isTagsExpanded ? 0 : 20)
                .fill(Color.black.opacity(0.9))
        )
        .offset(y: isTagsExpanded ? 0 : 0)
    }
}

// MARK: - 照片图像视图
struct PhotoImageView: View {
    let photo: PhotoItem
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
        // 1. 先显示缩略图（即时显示，无延迟）
        if let data = photo.thumbnailData, let image = UIImage(data: data) {
            self.fullImage = image
            self.isLoading = false
            print("✅ 显示缩略图: \(photo.assetIdentifier.prefix(8))...")
        } else {
            self.isLoading = false
            print("❌ 无法加载缩略图: \(photo.assetIdentifier.prefix(8))...")
        }
        
        // 2. 后台加载原图（从 PHAsset）
        Task {
            if let originalImage = await loadOriginalFromAsset() {
                await MainActor.run {
                    self.fullImage = originalImage
                    print("✅ 已加载原图: \(photo.assetIdentifier.prefix(8))... 尺寸: \(originalImage.size)")
                }
            } else {
                // 降级：继续使用缩略图
                print("⚠️ 原图加载失败，使用缩略图: \(photo.assetIdentifier.prefix(8))...")
            }
        }
    }
    
    private func loadOriginalFromAsset() async -> UIImage? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            manager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - 标签内容视图
struct TagsContentView: View {
    let visionInfo: PhotoVisionInfo
    let isExpanded: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Scene 标签
                if !visionInfo.sceneClassifications.isEmpty {
                    TagCategorySection(
                        title: "场景",
                        icon: "photo.on.rectangle",
                        color: .blue,
                        tags: visionInfo.sceneClassifications.map { classification in
                            TagDisplayItem(
                                name: classification.identifier,
                                confidence: classification.confidence
                            )
                        }
                    )
                }
                
                // Image 标签（已移除，因为与场景标签重复）
                // VNClassifyImageRequest 返回的就是场景分类
                
                // Object 标签
                if !visionInfo.recognizedObjects.isEmpty {
                    TagCategorySection(
                        title: "物体",
                        icon: "cube.box",
                        color: .orange,
                        tags: visionInfo.recognizedObjects.map { object in
                            TagDisplayItem(
                                name: object.identifier,
                                confidence: object.confidence
                            )
                        }
                    )
                }
            }
            .padding()
        }
        .opacity(isExpanded ? 1 : 0.6)
    }
}

// MARK: - 标签分类区块
struct TagCategorySection: View {
    let title: String
    let icon: String
    let color: Color
    let tags: [TagDisplayItem]
    
    // 按置信度降序排序
    private var sortedTags: [TagDisplayItem] {
        tags.sorted { $0.confidence > $1.confidence }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 分类标题
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            // 标签流式布局
            FlowLayout(spacing: 8) {
                ForEach(sortedTags) { tag in
                    TagChip(tag: tag, color: color)
                }
            }
        }
    }
}

// MARK: - 标签显示项
struct TagDisplayItem: Identifiable {
    let id = UUID()
    let name: String
    let confidence: Float
}

// MARK: - 标签芯片
struct TagChip: View {
    let tag: TagDisplayItem
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.subheadline)
            Text(String(format: "(%.1f)", tag.confidence))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
        .foregroundColor(.white)
    }
}

// MARK: - 流式布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    // 换行
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview
#Preview {
    PhotoDetailView(
        photos: [],
        initialIndex: 0,
        onDismiss: {}
    )
}

