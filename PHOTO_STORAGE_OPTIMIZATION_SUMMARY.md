# 照片存储优化实施总结

## 实施日期
2025年12月27日

## 目标
将 app 从"隐私模式（PHPicker）"改为"权限请求模式"，移除原图存储，从系统相册实时加载大图，节省 95%+ 存储空间。

## 已完成的改动

### 1. ✅ 权限请求流程 (HomeView.swift)

**添加的状态变量**:
```swift
@State private var showLimitedAccessGrid = false
@State private var showPermissionDeniedAlert = false
@State private var navigateToPhotoLibrary = false
```

**新增方法**:
- `checkPhotoLibraryPermission()` - 检查照片库权限状态
- `handleSelectedAssets(_ assets: [PHAsset])` - 处理从系统相册选择的照片

**权限处理逻辑**:
- `.authorized` → 进入系统相册
- `.limited` → 显示授权照片网格
- `.notDetermined` → 请求权限
- `.denied/.restricted` → 显示引导提示

### 2. ✅ 有限访问模式照片网格

**新建文件**:
- `LimitedLibraryPhotosView.swift` - 授权照片网格界面
  - 3列网格布局，正方形照片
  - 左上角加号按钮修改授权
  - 多选照片进行分析
  
- `LimitedLibraryPickerView.swift` - 系统有限照片库选择器封装
  - UIViewControllerRepresentable
  - 调用 `PHPhotoLibrary.shared().presentLimitedLibraryPicker()`

**组件**:
- `PhotoGridCell` - 网格单元格，显示缩略图和选中状态

### 3. ✅ 移除原图存储逻辑

**修改的文件**:

1. **CoreDataManager.swift**
   - 移除 `originalImageData` 保存逻辑
   - 只保存 `thumbnailData`（400px @ 0.7 quality）

2. **SimpleAnalysisPipeline.swift**
   - 删除 `result.originalImages` 的收集逻辑

3. **SelectedPhotosManager.swift**
   - 注释掉 `@Published var originalImages`
   - 移除相关赋值代码

4. **HomeView.swift**
   - 注释掉 `selectionManager.originalImages = images`

### 4. ✅ 修改大图加载逻辑

**PhotoDetailView.swift**:
- 添加 `import Photos`
- 修改 `loadFullImage()` 方法：
  1. 先显示缩略图（即时显示，无延迟）
  2. 后台从 PHAsset 加载原图
  3. 加载成功后替换为原图
  4. 失败则继续显示缩略图

- 新增 `loadOriginalFromAsset()` 方法：
  - 使用 `PHImageManager` 请求原图
  - `targetSize: PHImageManagerMaximumSize`
  - `isNetworkAccessAllowed: true`

**AnalysisResultView.swift**:
- 添加 `import Photos`
- 同样的渐进式加载逻辑
- 先显示缩略图，后台加载原图

### 5. ✅ 清理数据模型

**AlbumPhotosView.swift**:
- 修改 `PhotoItem` 结构：
  ```swift
  struct PhotoItem: Identifiable {
      let id: String
      let assetIdentifier: String  // 用于从 PHAsset 加载原图
      let visionInfo: PhotoVisionInfo?
      let thumbnailData: Data?  // 400px 缩略图
      // 删除: let originalImageData: Data?
  }
  ```
- 更新 `AlbumPhotosViewModel.loadPhotos()` 方法

## 数据流程

```
用户点击 Scanner
    ↓
检查照片库权限
    ↓
┌─────────────┬──────────────┬─────────────┐
│ Authorized  │   Limited    │   Denied    │
│ 系统相册    │  授权网格    │  引导提示   │
└─────────────┴──────────────┴─────────────┘
    ↓
选择照片 → 加载并压缩到 400px
    ↓
┌─────────────────┬──────────────────┐
│  颜色分析 256px │  AI 分析 400px   │
└─────────────────┴──────────────────┘
    ↓
保存到 CoreData
    ↓
只保存 thumbnailData (400px @ 0.7)
不保存 originalImageData ❌
    ↓
查看大图时
    ↓
1. 立即显示 thumbnailData
2. 后台从 PHAsset 加载原图
3. 加载成功后替换
```

## 预期效果

### 存储空间节省

| 场景 | 当前方案 | 优化后 | 节省 |
|------|---------|--------|------|
| 10张照片 | 20-50MB | 0.5-1.5MB | 95%+ |
| 50张照片 | 100-250MB | 2.5-7.5MB | 97%+ |
| 100张照片 | 200-500MB | 5-15MB | 97%+ |

### 功能影响

- ✅ 颜色分析：无影响（依然使用 256px）
- ✅ AI 视觉分析：无影响（依然使用 400px）
- ✅ 相册网格显示：无影响（使用 thumbnailData）
- ⚠️ 大图查看：轻微延迟（0.5-2秒），但先显示缩略图，体验流畅

### 用户体验

- ✅ 权限请求：符合 iOS 标准流程
- ✅ 有限访问：提供友好的照片网格界面
- ✅ 大图查看：渐进式加载，先快后精
- ✅ 存储节省：95%+ 的空间节省

## 文件清单

### 修改的文件 (6个)
1. `Project_Color/Views/HomeView.swift`
2. `Project_Color/Persistence/CoreDataManager.swift`
3. `Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift`
4. `Project_Color/ViewModels/SelectedPhotosManager.swift`
5. `Project_Color/Views/PhotoDetailView.swift`
6. `Project_Color/Views/AnalysisResultView.swift`
7. `Project_Color/Views/AlbumPhotosView.swift`

### 新建的文件 (3个)
1. `Project_Color/Views/LimitedLibraryPhotosView.swift`
2. `Project_Color/Views/Components/LimitedLibraryPickerView.swift`
3. `Project_Color/Views/Components/FullLibraryPickerView.swift`

## 注意事项

1. **CoreData 模型未修改**：`originalImageData` 字段仍在数据模型中，但不再使用。如需完全移除，需要创建新的 Core Data 模型版本并进行迁移。

2. **向后兼容**：旧数据中的 `originalImageData` 不会被删除，只是不再写入新数据。

3. **权限要求**：用户必须授予照片库访问权限才能查看原图。如果权限被拒绝，只能看到缩略图。

4. **网络访问**：如果照片存储在 iCloud 且设备离线，原图加载可能失败，此时会继续显示缩略图。

## 测试建议

1. **权限场景测试**：
   - 首次安装，请求权限
   - 授予完全访问权限
   - 授予有限访问权限
   - 拒绝权限

2. **照片加载测试**：
   - 本地照片加载
   - iCloud 照片加载
   - 照片被删除后的处理
   - 网络不可用时的降级

3. **性能测试**：
   - 大图加载速度
   - 内存占用
   - 存储空间节省

## 实施状态

✅ 所有计划任务已完成
✅ 代码无 linting 错误
✅ 功能实现符合设计要求

---

**实施完成时间**: 2025年12月27日
**实施者**: AI Assistant

