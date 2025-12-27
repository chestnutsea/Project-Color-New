# 显影页缓存验证修复

## 问题描述

新增照片分析后，进入显影 tab 页，点击某个形状（圆形、或者两种花朵），很可能点不动或者所有照片都聚集在其中某个形状里。但如果此时进入另一个 tab 再返回显影 tab，就能成功点击进入正确的聚类了。

## 问题根源

### 用户使用场景
1. 用户之前已经分析过照片（例如 50 张），显影 tab 有数据
2. 用户新增 10 张照片并分析完成（现在总共 60 张）
3. 用户进入显影 tab

### 代码问题

在 `EmergeView.swift` 的 `performClusteringWithCache` 方法中，内存缓存验证逻辑不完整：

```swift
// ❌ 原始代码（第 676-686 行）
if currentMode == developmentMode && isFavoriteOnly == favoriteOnly {
    if developmentMode == .shadow && !tonalSquares.isEmpty {
        print("📊 显影页：使用内存中的影调模式数据")
        isLoading = false
        return  // 直接返回，使用旧数据！
    } else if developmentMode != .shadow && !colorCircles.isEmpty {
        print("📊 显影页：使用内存中的色调/综合模式数据")
        isLoading = false
        return  // 直接返回，使用旧数据！
    }
}
```

**问题**：只检查了显影模式和收藏开关，没有检查照片数量是否变化。

### 导致的症状

使用旧的内存缓存数据时：
- **照片归属关系过时**：新增的 10 张照片没有被分配到任何簇
- **点击异常**：
  - 点击形状可能点不动（因为某些照片 ID 已经不存在）
  - 所有照片聚集在某个形状里（因为新照片没有被正确分配）

### 为什么切换 tab 后就好了？

切换到其他 tab 再返回时：
1. `onDisappear` 触发，`isAnimating = false`
2. `onAppear` 再次触发
3. 在 `onAppear` 中检测到照片数量变化（第 359-369 行）
4. 重置 `hasLoadedOnce = false`
5. 重新执行聚类，生成正确的照片归属关系

## 修复方案

### 修改位置

`EmergeView.swift` 的 `performClusteringWithCache` 方法（第 673-698 行）

### 修改内容

在使用内存缓存前，增加照片数量验证：

```swift
// ✅ 修复后的代码
func performClusteringWithCache(screenSize: CGSize) async {
    let developmentMode = BatchProcessSettings.developmentMode
    let favoriteOnly = BatchProcessSettings.developmentFavoriteOnly
    
    // ✅ 先获取当前照片数量，用于验证内存缓存是否有效
    let currentPhotoCount: Int
    if favoriteOnly {
        currentPhotoCount = await fetchFavoritePhotoCount()
    } else {
        currentPhotoCount = await fetchCurrentPhotoCount()
    }
    
    // ✅ 检查模式、收藏开关、照片数量都匹配才使用内存缓存
    if currentMode == developmentMode && 
       isFavoriteOnly == favoriteOnly && 
       analyzedPhotoCount == currentPhotoCount {  // 新增照片数量检查
        if developmentMode == .shadow && !tonalSquares.isEmpty {
            print("📊 显影页：使用内存中的影调模式数据（照片数: \(currentPhotoCount)）")
            isLoading = false
            return
        } else if developmentMode != .shadow && !colorCircles.isEmpty {
            print("📊 显影页：使用内存中的色调/综合模式数据（照片数: \(currentPhotoCount)）")
            isLoading = false
            return
        }
    } else if currentMode == developmentMode && 
              isFavoriteOnly == favoriteOnly && 
              analyzedPhotoCount != currentPhotoCount {
        // 照片数量变化，内存缓存失效
        print("📊 显影页：内存缓存失效（照片数 \(analyzedPhotoCount) → \(currentPhotoCount)），重新聚类")
    }
    
    // ... 继续执行磁盘缓存检查和聚类逻辑
}
```

### 关键改进

1. **提前获取照片数量**：在检查内存缓存前就获取当前照片数量
2. **三重验证**：
   - 显影模式匹配：`currentMode == developmentMode`
   - 收藏开关匹配：`isFavoriteOnly == favoriteOnly`
   - **照片数量匹配**：`analyzedPhotoCount == currentPhotoCount` ⭐️ 新增
3. **失效提示**：当照片数量不匹配时，打印明确的日志

## 修复效果

### 修复后的流程

1. 用户新增照片分析完成（50 → 60 张）
2. 进入显影 tab，触发 `onAppear`
3. `performClusteringWithCache` 被调用
4. 获取当前照片数量：60 张
5. **检查内存缓存**：
   - `currentMode == developmentMode` ✅
   - `isFavoriteOnly == favoriteOnly` ✅
   - `analyzedPhotoCount (50) == currentPhotoCount (60)` ❌
6. **内存缓存失效**，打印：`"内存缓存失效（照片数 50 → 60），重新聚类"`
7. 检查磁盘缓存，也失效（照片数量不匹配）
8. **重新聚类**，生成新的照片归属关系
9. 用户可以正常点击形状查看正确的照片

### 性能影响

- **无额外开销**：只是将照片数量获取提前，不增加额外的数据库查询
- **避免无效缓存**：防止使用过时的内存缓存，确保数据一致性

## 测试建议

### 测试场景 1：新增照片后进入显影 tab

1. 分析 50 张照片
2. 进入显影 tab，查看聚类效果
3. 返回，新增 10 张照片并分析
4. 再次进入显影 tab
5. **预期**：自动重新聚类，点击形状可以正常查看照片

### 测试场景 2：切换显影模式

1. 在色调模式下查看显影效果
2. 切换到影调模式
3. **预期**：正常显示影调模式的圆角正方形

### 测试场景 3：切换收藏过滤

1. 关闭收藏过滤，查看全部照片的显影效果
2. 开启收藏过滤
3. **预期**：只显示收藏照片的聚类结果

## 相关文件

- `Project_Color/Views/EmergeView.swift`：主要修改文件
- `Persistence/CoreDataManager.swift`：照片数量查询方法

## 修复日期

2025-12-26

