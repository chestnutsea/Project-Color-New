# 颜色分析系统实现路线图

## 项目概述

基于 Median-Cut + LAB 聚类 + 语义命名的完整颜色分析系统，采用迭代式开发策略。

### 总体架构

```
照片输入 → 主色提取 → LAB空间聚类 → 语义命名 → 结果展示
```

### 技术栈
- **主色提取**：Median-Cut (MMCQ) 算法
- **聚类算法**：KMeans（LAB 空间）
- **自动选K**：Silhouette Score 评估
- **语义命名**：CSS Colors (140色) + xkcd (950+色)
- **持久化**：Core Data
- **性能**：并发处理 + 内存优化

---

## Micro-Phase 1: 核心验证版 ✅ 当前阶段

### 目标
验证整体流程可行性，快速看到可运行的 Demo

### 范围

#### 1. 数据结构（内存临时存储，不涉及 Core Data）
- `AnalysisResult`: ObservableObject，存储分析结果
- `ColorCluster`: 颜色簇结构（RGB、名称、照片数）
- `PhotoColorInfo`: 单张照片的主色信息

#### 2. 超简化主色提取
- 使用 Core Image 的颜色量化
- 或集成轻量级第三方库
- 只在 **RGB 空间**操作（不转 LAB）
- 提取每张照片的 5 个主色

#### 3. 固定 K=5 的 KMeans 聚类
- 在 **RGB 空间**聚类
- 使用欧氏距离（不用 ΔE₀₀）
- k-means++ 初始化
- 最大迭代 50 次

#### 4. 基础颜色命名
- 20 个基础色名：
  - 红、橙、黄、黄绿、绿、青、蓝、紫、粉、棕
  - 黑、深灰、灰、浅灰、白
  - 米色、奶油色、土色、橄榄绿、酒红
- 基于 RGB 到 HSL 转换的简单 Hue 角度映射

#### 5. 最小化 UI
- **HomeView**：
  - 显示"颜色提取中...正在处理 X/Y 张照片"
  - 简单进度条
- **AnalysisResultView**（新建）：
  - 显示 5 个聚类色块
  - 每个色块下显示：颜色名称 + 照片数量
  - 点击色块显示该类别的照片缩略图

#### 6. 串行处理
- 不使用并发优化
- 一张张处理照片
- 重点在于流程验证

### 技术实现

**新建文件**：
- `Services/ColorExtraction/SimpleColorExtractor.swift`
- `Services/Clustering/SimpleKMeans.swift`
- `Services/ColorNaming/BasicColorNamer.swift`
- `Models/AnalysisModels.swift`
- `ViewModels/AnalysisResultViewModel.swift`
- `Views/AnalysisResultView.swift`

### 工作量估算
- **40-60 次工具调用**
- **单次会话可完成**
- **质量保障：90%**

### 验收标准
- ✅ 用户选择照片 → 拖拽到 scanner
- ✅ 显示处理进度
- ✅ 跳转到结果页，显示 5 个颜色类别
- ✅ 点击类别查看照片
- ✅ 无崩溃，流程完整

---

## Micro-Phase 2: LAB 转换与 CSS 颜色命名

### 目标
提升颜色准确性和命名质量

### 范围

#### 1. 颜色空间转换
- 实现 RGB → LAB 转换（D65 白点）
- 实现 LAB → RGB 转换
- 实现 RGB → HSL 转换
- 实现简化版 ΔE 色差计算（欧氏距离）

#### 2. CSS 颜色命名（140 色）
- 创建 CSS Colors 数据文件（JSON）
- 实现 LAB 空间最近邻匹配
- 替换 Phase 1 的基础命名

#### 3. 升级聚类
- 将 KMeans 从 RGB 空间迁移到 LAB 空间
- 使用 ΔE 距离替代欧氏距离

#### 4. 中性色筛选（可选）
- 筛选低饱和度（S < 0.18）颜色
- 作为独立的 "Neutral" 簇

### 技术实现

**新建文件**：
- `Services/ColorConversion/ColorSpaceConverter.swift`
- `Services/ColorNaming/ColorNameResolver.swift`
- `Resources/css-colors.json`

**修改文件**：
- `Services/Clustering/SimpleKMeans.swift` → 支持 LAB 空间

### 工作量估算
- **40-50 次工具调用**

### 验收标准
- ✅ 聚类结果基于 LAB 空间
- ✅ 颜色命名使用 CSS 标准色名
- ✅ 中性色单独识别

---

## Micro-Phase 3: Core Data 持久化

### 目标
实现结果持久化，支持历史会话查看

### 范围

#### 1. Core Data 模型扩展

**新增实体**：

**AnalysisSessionEntity**
- id: UUID
- timestamp: Date
- totalPhotoCount: Int16
- processedCount: Int16
- failedCount: Int16
- optimalK: Int16（当前固定为5，后续动态）
- status: String

**ColorClusterEntity**
- id: UUID
- clusterIndex: Int16
- centroidL, centroidA, centroidB: Double
- centroidHex: String
- colorName: String
- sampleCount: Int16
- sampleRatio: Double

**PhotoAnalysisEntity**
- id: UUID
- assetLocalIdentifier: String
- sha256Hash: String
- primaryColorName: String
- primaryClusterIndex: Int16
- mixVector: Binary
- dominantColors: Binary（5个主色的 LAB + RGB + 权重）

#### 2. 数据迁移
- 将 Phase 1/2 的内存结构迁移到 Core Data
- 实现 CoreDataManager 扩展方法

#### 3. 历史会话 UI
- 在 HomeView 添加"历史记录"按钮
- 创建 `HistoryListView` 显示所有会话
- 点击会话查看结果

### 技术实现

**修改文件**：
- `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`
- `Persistence/CoreDataManager.swift`

**新建文件**：
- `ViewModels/AnalysisSessionManager.swift`
- `Views/HistoryListView.swift`

### 工作量估算
- **50-60 次工具调用**

### 验收标准
- ✅ 分析结果保存到 Core Data
- ✅ 应用重启后仍可查看历史结果
- ✅ 如果原照片未删除，可以索引回原图

---

## Micro-Phase 4: Silhouette 自动选 K + 完善 UI

### 目标
实现自适应聚类数量，优化用户体验

### 范围

#### 1. Silhouette Score 评估
- 实现 Silhouette Score 计算
- 对 K ∈ [3, 12] 进行评估
- 自动选择最优 K
- 算法：`s(i) = (b(i) - a(i)) / max(a(i), b(i))`

#### 2. 动态 K 值聚类
- 替换固定 K=5
- 根据 Silhouette 评估结果动态聚类

#### 3. UI 完善

**AnalysisResultView**：
- 显示自适应的 K 个类别（3-12 个）
- 添加类别质量指标（Silhouette Score）

**ClusterDetailView**（新建）：
- 点击类别进入详情页
- 显示该类别的所有照片网格
- 显示类别质心色和名称

**PhotoAnalysisDetailView**（新建）：
- 点击照片查看详情
- 显示 5 个主色（色块 + 名称 + 占比）
- 显示所属主簇
- 显示 ΔE 和置信度
- 提供"查看原图"按钮（如果照片存在）

#### 4. 失败统计
- 统计处理失败的照片数量
- 在结果页底部显示："处理失败：X 张"

#### 5. 取消功能
- 实现 CancellationToken
- 在 HomeView 添加"取消"按钮
- 中断处理流程

### 技术实现

**新建文件**：
- `Services/Clustering/SilhouetteEvaluator.swift`
- `Views/ClusterDetailView.swift`
- `Views/PhotoAnalysisDetailView.swift`
- `Models/CancellationToken.swift`

**修改文件**：
- `Services/Clustering/SimpleKMeans.swift` → 支持动态 K
- `Views/HomeView.swift` → 添加取消按钮

### 工作量估算
- **50-60 次工具调用**

### 验收标准
- ✅ 聚类数量自动确定（3-12 个）
- ✅ 完整的三级页面：结果页 → 类别详情 → 照片详情
- ✅ 显示失败统计
- ✅ 支持取消处理

---

## Micro-Phase 5: 并发优化 + 自适应更新

### 目标
提升性能和长期可维护性

### 范围

#### 1. 并发优化

**并发主色提取**：
- 使用 DispatchQueue.concurrent
- 限制并发数为 CPU 核心数
- 使用 DispatchSemaphore 控制
- 使用 autoreleasepool 释放内存

**批量保存**：
- 每处理 50 张照片批量保存一次
- 减少 Core Data 写入频率

**缩略图优化**：
- 使用 PHImageManager 异步加载
- 最大边 300px
- 避免加载完整图像

#### 2. xkcd 颜色数据集
- 集成 xkcd 950+ 色
- 创建 `Resources/xkcd-colors.json`
- 扩展颜色命名精度

#### 3. 自适应更新机制

**触发条件**：
- 新增照片数量达到阈值（如 5000 张）
- 或定期检查（如季度）

**更新流程**：
1. 加载所有历史 PhotoAnalysisEntity
2. 提取所有主色点
3. 重新计算最优 K（Silhouette）
4. 重新聚类
5. **簇对齐**：基于质心 ΔE 匹配新旧簇
6. **簇合并**：ΔE < 5 的簇合并
7. **簇删除**：占比 < 1% 的簇标记为过时
8. **新簇识别**：无法匹配的新簇标记为"新发现"
9. 更新所有照片的簇标签
10. 生成更新报告

**UI 通知**：
- 显示"发现 X 个新色系"
- 显示"合并了 Y 个相似色系"

#### 4. Median-Cut 优化（可选）
- 替换简化版主色提取
- 实现完整的 MMCQ 算法
- 或集成 swift-vibrant 库

#### 5. ΔE₀₀ 精确计算
- 实现 CIEDE2000 色差公式
- 替换简化版欧氏距离

### 技术实现

**新建文件**：
- `Services/Clustering/ClusterUpdateManager.swift`
- `Services/Clustering/UpdateTriggerManager.swift`
- `Services/ColorExtraction/MedianCutExtractor.swift`（如果自实现）
- `Services/ColorConversion/DeltaE2000.swift`
- `Resources/xkcd-colors.json`

**修改文件**：
- `Services/ColorAnalysis/ColorAnalysisPipeline.swift` → 添加并发控制
- `Views/AnalysisResultView.swift` → 显示更新通知

### 工作量估算
- **60-80 次工具调用**

### 验收标准
- ✅ 处理速度明显提升（并发优化）
- ✅ 支持 xkcd 命名（更准确）
- ✅ 自适应更新机制正常工作
- ✅ 簇对齐、合并、删除逻辑正确
- ✅ 更新通知 UI 完善

---

## 总结

### 各阶段关系

```
Phase 1 (核心验证)
    ↓
Phase 2 (LAB + CSS命名) ← 颜色准确性提升
    ↓
Phase 3 (Core Data) ← 持久化支持
    ↓
Phase 4 (自动选K + UI完善) ← 用户体验优化
    ↓
Phase 5 (并发 + 自适应) ← 性能与可维护性
```

### 总工作量
- **Phase 1**：40-60 次调用
- **Phase 2**：40-50 次调用
- **Phase 3**：50-60 次调用
- **Phase 4**：50-60 次调用
- **Phase 5**：60-80 次调用
- **总计**：240-310 次调用

### 迭代优势
1. **风险可控**：每阶段独立验证
2. **及时反馈**：每完成一阶段可以实际测试
3. **灵活调整**：根据实际效果调整后续计划
4. **质量保证**：每阶段工作量在舒适区内

---

## 当前状态

- ✅ 路线图制定完成
- 🚧 Micro-Phase 1 开发中
- ⏳ Micro-Phase 2-5 待开始

---

## 参考文档

- `Image Classification.txt` - 技术方案详细说明
- `Dominant Color Extraction and Image Categorization.txt` - 算法原理
- `Core Data Structure.md` - 数据模型设计

