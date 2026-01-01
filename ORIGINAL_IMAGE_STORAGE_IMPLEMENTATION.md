# 原图存储与大图查看功能实现

## 实现目标

1. **在 Core Data 中存储原图**，用于相册和显影 tab 的大图查看
2. **修复显影页聚类照片的大图显示问题**，让点击照片后能查看大图

## 实现内容

### 1. Core Data 模型更新

**文件：** `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`

**修改：** 在 `PhotoAnalysisEntity` 中添加 `originalImageData` 字段

```xml
<attribute name="originalImageData" optional="YES" attributeType="Binary" allowsExternalBinaryDataStorage="YES"/>
```

**说明：**
- 使用 `Binary` 类型存储图片数据
- 设置 `allowsExternalBinaryDataStorage="YES"` 让 Core Data 自动管理大文件存储
- 当文件较大时，Core Data 会将其存储在外部，只在数据库中保存引用

### 2. 保存逻辑更新

**文件：** `Project_Color/Persistence/CoreDataManager.swift`

**修改：** 在保存分析结果时，同时保存原图数据

```swift
// 生成并保存缩略图和原图
if index < result.compressedImages.count {
    let compressedImage = result.compressedImages[index]
    // 保存缩略图（用于列表展示）
    if let thumbnailData = compressedImage.jpegData(compressionQuality: 0.7) {
        photoAnalysis.thumbnailData = thumbnailData
        print("💾 保存缩略图（隐私模式）: \(thumbnailData.count) bytes")
    }
    
    // ✅ 保存原图数据（用于大图查看）
    if index < result.originalImages.count {
        let originalImage = result.originalImages[index]
        // 使用较高质量压缩原图（0.85），平衡质量和存储空间
        if let originalImageData = originalImage.jpegData(compressionQuality: 0.85) {
            photoAnalysis.originalImageData = originalImageData
            print("💾 保存原图（隐私模式）: \(originalImageData.count) bytes")
        }
    }
}
```

**压缩质量说明：**
- **缩略图**：0.7（用于列表展示，优先考虑存储空间）
- **原图**：0.85（用于大图查看，优先考虑质量）

### 3. PhotoItem 数据结构更新

**文件：** `Project_Color/Views/AlbumPhotosView.swift`

**修改：** 添加 `originalImageData` 字段

```swift
struct PhotoItem: Identifiable {
    let id: String
    let assetIdentifier: String
    let visionInfo: PhotoVisionInfo?
    let thumbnailData: Data?  // 缩略图
    let originalImageData: Data?  // ✅ 原图数据
}
```

**加载逻辑：**

```swift
return PhotoItem(
    id: assetId,
    assetIdentifier: assetId,
    visionInfo: visionInfo,
    thumbnailData: entity.thumbnailData,
    originalImageData: entity.originalImageData  // ✅ 从 Core Data 加载
)
```

### 4. PhotoDetailView 更新

**文件：** `Project_Color/Views/PhotoDetailView.swift`

**修改：** 优先加载原图，回退到缩略图

```swift
private func loadFullImage() {
    // ✅ 优先加载原图（如果有），否则显示缩略图
    if let data = photo.originalImageData, let image = UIImage(data: data) {
        DispatchQueue.main.async {
            self.fullImage = image
            self.isLoading = false
            print("✅ 加载原图成功")
        }
    } else if let data = photo.thumbnailData, let image = UIImage(data: data) {
        DispatchQueue.main.async {
            self.fullImage = image
            self.isLoading = false
            print("⚠️ 原图不可用，使用缩略图")
        }
    } else {
        DispatchQueue.main.async {
            self.isLoading = false
            print("❌ 无法加载照片")
        }
    }
}
```

### 5. ClusterDetailView 大图查看功能

**文件：** `Project_Color/Views/AnalysisResultView.swift`

**新增组件：**

1. **ClusterPhotoDetailWrapper** - 照片索引包装器
2. **ClusterPhotoDetailView** - 聚类照片详情视图（支持左右滑动）
3. **ClusterPhotoImageView** - 单张照片图像视图（从 Core Data 加载原图）

**实现逻辑：**

```swift
// 1. 在 ClusterDetailView 中添加照片点击事件
LazyVGrid(columns: columns, spacing: 10) {
    ForEach(Array(photosInCluster.enumerated()), id: \.element.id) { index, photoInfo in
        AnalysisPhotoThumbnail(image: thumbnailProvider(photoInfo.assetIdentifier))
            .onTapGesture {
                selectedPhotoIndex = index  // ✅ 点击照片
            }
    }
}

// 2. 使用 fullScreenCover 展示大图
.fullScreenCover(item: $selectedPhotoIndex) { wrapper in
    ClusterPhotoDetailView(
        photoInfos: photosInCluster,
        initialIndex: wrapper.index,
        thumbnailProvider: thumbnailProvider,
        onDismiss: { selectedPhotoIndex = nil }
    )
}
```

**ClusterPhotoImageView 加载逻辑：**

```swift
private func loadFullImage() {
    Task.detached(priority: .userInitiated) {
        let context = CoreDataManager.shared.newBackgroundContext()
        var originalImageData: Data?
        var thumbnailData: Data?
        
        context.performAndWait {
            let request = PhotoAnalysisEntity.fetchRequest()
            request.predicate = NSPredicate(format: "assetLocalIdentifier == %@", assetIdentifier)
            request.fetchLimit = 1
            
            if let entity = try? context.fetch(request).first {
                originalImageData = entity.originalImageData
                thumbnailData = entity.thumbnailData
            }
        }
        
        await MainActor.run {
            // 优先使用原图
            if let data = originalImageData, let image = UIImage(data: data) {
                self.fullImage = image
                self.isLoading = false
            } else if let data = thumbnailData, let image = UIImage(data: data) {
                self.fullImage = image
                self.isLoading = false
            } else if let image = thumbnailProvider(assetIdentifier) {
                // 回退：使用内存缓存
                self.fullImage = image
                self.isLoading = false
            } else {
                self.isLoading = false
            }
        }
    }
}
```

## 数据流程

### 分析时（保存）

```
用户选择照片
    ↓
PhotosPicker 加载原图 → result.originalImages (内存)
    ↓
压缩后用于 AI 分析 → result.compressedImages (内存)
    ↓
保存到 Core Data:
    - thumbnailData (压缩质量 0.7)
    - originalImageData (压缩质量 0.85) ✅ 新增
```

### 查看时（加载）

```
相册页/显影页 → 点击照片
    ↓
从 Core Data 读取:
    - 优先：originalImageData (原图)
    - 回退：thumbnailData (缩略图)
    ↓
显示大图
```

## 存储空间估算

假设一张照片：
- **原图尺寸**：4000x3000 (12MP)
- **压缩质量 0.85**：约 1-3 MB
- **缩略图**：约 20-50 KB

100 张照片：
- **原图总计**：100-300 MB
- **缩略图总计**：2-5 MB

## 优势

1. **隐私模式兼容**：不需要照片库权限
2. **跨设备同步**：通过 iCloud 同步（如果启用）
3. **性能优化**：
   - 列表使用缩略图（快速加载）
   - 大图使用原图（高质量显示）
4. **自动管理**：Core Data 自动处理大文件存储

## 注意事项

1. **首次使用**：需要重新分析照片才能生成 `originalImageData`
2. **旧数据兼容**：旧的分析结果没有原图，会回退到缩略图
3. **存储空间**：原图会占用较多存储空间，建议用户定期清理旧数据
4. **iCloud 同步**：如果启用 iCloud 同步，原图也会同步到云端

## 测试建议

1. **新分析**：分析几张照片，验证原图是否正确保存
2. **相册页**：从相册页点击照片，验证是否显示原图
3. **显影页**：点击彩色形状 → 点击照片，验证是否显示原图
4. **旧数据**：查看旧的分析结果，验证是否正确回退到缩略图

## 完成日期

2025-12-26


