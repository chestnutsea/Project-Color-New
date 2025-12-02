# 影调模式实现总结

## 概述

本次实现为显影页（EmergeView）新增了**影调模式**的支持，并为所有三种模式（色调、影调、综合）添加了聚类缓存机制。

## 新增功能

### 1. 照片分析新增属性

在 `PhotoAnalysisEntity` 中新增两个属性：

- **brightnessMedian** (Float): 明度中位数 (0-100)，从 CDF 的 50% 分位数计算
- **brightnessContrast** (Float): 对比度 (0-100)，从 CDF 的 95% 分位 - 5% 分位计算

### 2. 聚类缓存机制

新增 `DevelopmentClusterCacheEntity` 实体，用于存储三种模式的聚类结果：

| 属性 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| mode | String | "tone" / "shadow" / "comprehensive" |
| lastUpdated | Date | 最后更新时间 |
| photoCount | Int32 | 聚类时的照片总数 |
| clustersData | Binary | 聚类结果 (JSON) |

### 3. 缓存失效策略

- 进入显影页时，检查当前模式的缓存是否存在
- 如果缓存的 `photoCount` 与当前照片总数一致，直接加载缓存
- 如果不一致（用户分析了新照片），重新聚类并更新缓存
- 切换模式时，如果该模式没有缓存，执行聚类

### 4. 影调模式聚类

- **输入向量**: (明度中位数, 对比度) 二维向量
- **聚类算法**: KMeans，自动选择最优 K 值 (3-18)
- **距离计算**: 二维欧几里得距离

### 5. 影调模式可视化

质心显示为**圆角正方形**：

| 属性 | 计算方式 |
|------|----------|
| 边长 | 20-80px，与照片数量正相关（平方根归一化） |
| 颜色 | 灰度，L=0 纯黑，L=100 纯白 |
| 圆角半径 | 边长 × 0.5 × (对比度/100)，对比度越高越圆 |

## 文件修改清单

### Core Data 模型
- `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`
  - PhotoAnalysisEntity 新增 `brightnessMedian`, `brightnessContrast`
  - 新增 `DevelopmentClusterCacheEntity`

### 数据模型
- `Project_Color/Models/AnalysisModels.swift`
  - PhotoColorInfo 新增 `brightnessMedian`, `brightnessContrast`
  - 新增 `computeBrightnessStatistics()` 方法

### 分析流程
- `Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift`
  - 在照片分析时调用 `computeBrightnessStatistics()`

### 持久化
- `Project_Color/Persistence/CoreDataManager.swift`
  - 保存 `brightnessMedian`, `brightnessContrast`
  - 新增 `DevelopmentClusterCache` 结构
  - 新增 `saveDevelopmentClusterCache()`, `loadDevelopmentClusterCache()` 方法

### 缓存
- `Project_Color/Services/Cache/PhotoColorCache.swift`
  - 加载时复用 `brightnessMedian`, `brightnessContrast`

### 视图
- `Project_Color/Views/EmergeView.swift`
  - 新增 `TonalSquare` 数据结构
  - 新增 `performClusteringWithCache()` 缓存加载逻辑
  - 新增 `performTonalClusteringBackground()` 影调聚类
  - 新增 `glowingSquareGlow()` 发光效果
  - 新增 `updateTonalSquareMotion()` 运动更新

- `Project_Color/Views/AnalysisLibraryView.swift`
  - 加载时复用 `brightnessMedian`, `brightnessContrast`

## 布局常量

```swift
// 影调模式 - 圆角正方形参数
static let tonalMinSize: CGFloat = 20       // 最小边长
static let tonalMaxSize: CGFloat = 80       // 最大边长
static let tonalMaxCornerRatio: CGFloat = 0.5  // 最大圆角比例
```

## 使用说明

1. 在「我的」→「暗房参数」→「显影解析模式」中选择「影调模式」
2. 进入「显影」页面
3. 系统会自动加载缓存或执行聚类
4. 点击圆角正方形可查看归属的照片

## 注意事项

- 旧照片如果没有 `brightnessMedian` 和 `brightnessContrast`，系统会自动从 `brightnessCDF` 计算
- 首次使用影调模式需要等待聚类完成
- 缓存会在照片数量变化时自动失效

