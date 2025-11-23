# 照片选择流程重构

## 修改日期
2025-11-23

## 概述

完全重构了照片选择和分析流程，使用 Apple 原生的 PHPickerViewController，移除了相册选择和图像类型分类，简化了用户体验。

## 主要变更

### Phase 1: Core Data 模型更新

#### 添加字段
- `isFavorite` (Boolean): 收藏状态，默认 false
- `customName` (String): 自定义名称
- `customDate` (Date): 自定义日期

#### 移除字段
- `isPersonalWork`: 不再区分"我的作品"和"其他图像"

#### 新增方法
- `generateSessionName()`: 自动生成名称（格式：YYYY 年 M 月 D 日）
- `updateSessionFavoriteStatus()`: 更新收藏状态

### Phase 2: 照片选择器

#### 新文件
- `PhotoPickerView.swift`: 封装 PHPickerViewController
  - 支持无限多选
  - 保持选择顺序
  - 只选择图片

- `SelectedPhotosManager.swift`: 管理选中照片
  - 替代原来的 `PhotoSelectionManager`
  - 按拍摄日期排序
  - 获取最新的 N 张照片

#### HomeView 更新
- 使用 `SelectedPhotosManager` 替代 `PhotoSelectionManager`
- 点击 scanner 直接打开 PHPickerViewController
- 照片堆显示最新的 3 张照片
- 移除相册列表视图

### Phase 3: 移除图像类型选择

#### 移除的功能
- 图像类型选择弹窗（我的作品/其他图像）
- `ImageTypeSelectionAlert`
- `handleImageTypeSelection()` 方法
- `AnalysisResult.isPersonalWork` 字段

#### 简化的流程
```
用户选择照片 → 拖动到 scanner → 直接开始分析 → 保存到 Core Data
```

#### 自动命名
- 格式：`YYYY 年 M 月 D 日`
- 同一天多次分析自动添加后缀：`(2)`, `(3)` 等
- 示例：
  - 第一次：`2025 年 11 月 23 日`
  - 第二次：`2025 年 11 月 23 日 (2)`
  - 第三次：`2025 年 11 月 23 日 (3)`

### Phase 4: 结果页收藏功能

#### 新文件
- `FavoriteAlertView.swift`: 收藏弹窗
  - 名称输入框（预填充自动生成的名称）
  - 日期选择器（默认当天）
  - 取消/确认按钮

#### AnalysisResultView 更新
- 导航栏添加爱心图标
  - 未收藏：空心 `heart`
  - 已收藏：实心 `heart.fill`（红色）
- 点击爱心：
  - 未收藏 → 显示收藏弹窗
  - 已收藏 → 直接取消收藏
- 自动加载收藏状态

#### AnalysisResult 更新
- 添加 `sessionId` 字段
- 保存后自动设置 sessionId

## 数据流

### 照片选择流程
```
1. 用户点击 scanner
   ↓
2. 检查相册权限
   ↓
3. 打开 PHPickerViewController
   ↓
4. 用户选择照片（支持多选、预览、长按）
   ↓
5. 照片保存到 SelectedPhotosManager
   ↓
6. 照片堆显示最新 3 张
   ↓
7. 用户拖动照片堆到 scanner
   ↓
8. 开始分析
```

### 分析保存流程
```
1. 分析完成
   ↓
2. 自动生成名称（YYYY 年 M 月 D 日）
   ↓
3. 检查同名会话，添加后缀
   ↓
4. 保存到 Core Data
   - isFavorite = false
   - customName = 生成的名称
   - customDate = 当天日期
   ↓
5. 设置 result.sessionId
   ↓
6. 跳转到结果页
```

### 收藏流程
```
1. 用户点击爱心图标
   ↓
2. 显示收藏弹窗
   - 默认名称：YYYY 年 M 月 D 日
   - 默认日期：当天
   ↓
3. 用户修改名称/日期（可选）
   ↓
4. 点击确认
   ↓
5. 更新 Core Data
   - isFavorite = true
   - customName = 用户输入
   - customDate = 用户选择
   ↓
6. 爱心图标变为实心红色
```

## 待完成任务

### Phase 5: 重构 AlbumLibraryView
- [ ] 添加"收藏"/"全部"两个 tab
- [ ] 显示分析结果卡片（cover + 名称 + 日期）
- [ ] 点击卡片进入结果详情页

### Phase 6: 更新 AnalysisHistoryView
- [ ] 添加"收藏"/"全部"筛选

### 清理工作
- [ ] 移除 `AlbumListView.swift`
- [ ] 移除 `PhotoSelectionManager.swift`
- [ ] 移除 `ImageTypeSelectionAlert` 相关代码

## 技术细节

### PHPickerViewController 配置
```swift
var configuration = PHPickerConfiguration(photoLibrary: .shared())
configuration.selectionLimit = 0  // 无限制
configuration.filter = .images    // 只选择图片
configuration.selection = .ordered  // 保持选择顺序
```

### 名称生成算法
```swift
private func generateSessionName(for date: Date, context: NSManagedObjectContext) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy 年 M 月 d 日"
    let baseName = formatter.string(from: date)
    
    // 查询同一天的会话
    // 找出已使用的后缀数字
    // 返回第一个未使用的数字
}
```

### 收藏状态管理
```swift
func updateSessionFavoriteStatus(
    sessionId: UUID,
    isFavorite: Bool,
    customName: String? = nil,
    customDate: Date? = nil
) throws
```

## 用户体验改进

### 简化的流程
- **之前**：选择相册 → 查看照片 → 选择图像类型 → 分析
- **现在**：选择照片 → 分析

### 更灵活的选择
- 支持从不同相册选择照片
- 无多选数量限制
- 保持用户选择顺序
- 支持预览和长按

### 更清晰的组织
- 默认按日期自动命名
- 支持收藏重要的分析结果
- 可自定义名称和日期

## 兼容性

- iOS 14.0+（PHPickerViewController 要求）
- 向后兼容现有的分析数据
- Core Data 自动迁移

## 测试建议

1. **照片选择**
   - 测试多选功能
   - 测试照片顺序
   - 测试权限请求

2. **自动命名**
   - 测试同一天多次分析
   - 测试名称冲突处理

3. **收藏功能**
   - 测试收藏/取消收藏
   - 测试自定义名称
   - 测试日期选择器

4. **数据持久化**
   - 测试 Core Data 保存
   - 测试收藏状态加载
   - 测试数据迁移

