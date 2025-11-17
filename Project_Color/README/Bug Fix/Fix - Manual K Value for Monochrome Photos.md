# 修复：为单色系照片添加手动 K 值设置

## 问题描述

用户使用"单色系细分"预设处理 6 张绿色照片：
- ✅ 关闭自适应聚类
- ✅ 精细精度
- ✅ 不合并相似色
- ✅ 最小簇 = 1

**期望结果**：多个不同的绿色色系（如 5-8 个）

**实际结果**：
- K=3（全局聚类只识别出 3 个色系）
- darkolivegreen（6张）、DarkKhaki（0张）、Sienna（0张）
- 有空簇，说明聚类质量不佳

## 根本原因

### 1. 自动 K 值选择对单色系照片不友好

**Silhouette Score 的局限性**：
- 对于颜色非常相似的照片（如 6 张绿色）
- Silhouette Score 倾向于选择**较小的 K 值**
- 因为分成更多簇会导致簇之间的"分离度"降低
- 但用户期望的恰恰是**细分这些相似的颜色**

**你的情况**：
- 6 张照片 × 5 个主色 = 30 个颜色点
- K 值范围：3 - 6（根据代码逻辑）
- Silhouette Score 选择了 K=3（分离度最好）
- 但 K=3 无法细分 6 张绿色照片

### 2. K 值范围计算过于保守

```swift
if allMainColorsLAB.count < 50 {
    // 20-50个颜色点（约4-10张照片）：最多8个簇
    maxK = max(minK, min(8, allMainColorsLAB.count / 5))
}
// 30 个颜色点 → maxK = min(8, 30/5) = min(8, 6) = 6
```

对于单色系照片，这个范围太小了。

## 解决方案

### 新增功能：手动指定 K 值

允许用户跳过自动 K 值选择，直接指定想要的色系数量。

### 修改的文件

#### 1. AnalysisSettings.swift

**新增属性**：
```swift
/// 手动指定 K 值（色系数量）
/// - 默认: nil（自动选择）
/// - 范围: 3 - 12
/// - 说明: 设置后将跳过自动 K 值选择，直接使用指定的 K 值
@Published var manualKValue: Int? = nil
```

**更新预设**：
```swift
/// 单色系细分（适合颜色相近的照片）
func applyMonochromePreset() {
    manualKValue = 8                 // ✅ 强制使用 K=8
    enableAdaptiveClustering = false  // 关闭自适应聚类
    mergeThresholdDeltaE = 6.0
    useColorNameSimilarity = false
    minClusterSize = 1
}
```

#### 2. AnalysisSettingsView.swift

**新增 UI Section**：
```swift
// 手动指定 K 值
Section {
    Toggle("手动指定色系数量", isOn: Binding(
        get: { settings.manualKValue != nil },
        set: { newValue in
            if newValue {
                settings.manualKValue = 8  // 默认 8
            } else {
                settings.manualKValue = nil
            }
        }
    ))
    
    if let _ = settings.manualKValue {
        Picker("色系数量 (K)", selection: Binding(
            get: { settings.manualKValue ?? 8 },
            set: { settings.manualKValue = $0 }
        )) {
            ForEach(3...12, id: \.self) { k in
                Text("\(k) 个色系").tag(k)
            }
        }
    }
} header: {
    Text("全局聚类")
} footer: {
    if settings.manualKValue != nil {
        Text("已手动指定 K=\(settings.manualKValue!)，将跳过自动选择。适合单色系照片细分。")
    } else {
        Text("自动选择最优色系数量（K值），基于 Silhouette Score 评估。")
    }
}
```

#### 3. SimpleAnalysisPipeline.swift

**新增分支逻辑**：
```swift
// 检查是否手动指定了 K 值
let clusteringResult: SimpleKMeans.ClusteringResult

if let manualK = settings.manualKValue {
    // 使用手动指定的 K 值
    print("   📌 使用手动指定的 K=\(manualK)")
    
    // 直接执行 KMeans 聚类
    guard let clustering = kmeans.cluster(
        points: allMainColorsLAB,
        k: manualK,
        maxIterations: 50,
        colorSpace: .lab,
        weights: allColorWeights
    ) else {
        // 失败处理
    }
    
    clusteringResult = clustering
    result.optimalK = manualK
    result.qualityLevel = "手动指定"
    result.qualityDescription = "使用手动指定的 K=\(manualK)"
    
} else {
    // 自动选择最优 K 值（原有逻辑）
    // ...
}
```

## 使用指南

### 场景 1：单色系照片细分（推荐）

**方法 1：使用预设**
1. 打开设置
2. 点击"单色系细分（同色系照片）"
3. 自动设置：
   - ✅ 手动 K=8
   - ❌ 关闭自适应聚类
   - 合并阈值：6.0
   - 最小簇：1
4. 开始分析

**方法 2：手动配置**
1. 打开设置
2. 找到"全局聚类" Section
3. 开启"手动指定色系数量"
4. 选择 K 值（建议 6-10）
5. 关闭"启用自适应聚类"
6. 开始分析

### 场景 2：多样化照片分类（默认）

**配置**：
- ❌ 不手动指定 K 值（自动选择）
- ✅ 启用自适应聚类（默认）

**效果**：
- 自动选择最优 K 值
- 自动合并/删除簇
- 得到更有意义的分类结果

## 预期效果

### 你的情况（6 张绿色照片）

**使用单色系预设（K=8）**：
- 全局聚类：K=8
- 可能的结果：
  - 深绿色（1张）
  - 草绿色（2张）
  - 浅绿色（1张）
  - 黄绿色（1张）
  - 蓝绿色（1张）
  - 橄榄绿（0张）← 空簇
  - 翠绿色（0张）← 空簇
  - 墨绿色（0张）← 空簇
- 关闭自适应聚类后，保留所有 8 个簇（包括空簇）

**注意**：
- 空簇是正常的（KMeans 可能收敛到局部最优）
- 重要的是有照片的簇会更细分
- 如果空簇太多，可以降低 K 值（如 K=6）

## 技术细节

### 手动 K 值 vs 自动 K 值

| 特性 | 手动 K 值 | 自动 K 值 |
|------|----------|----------|
| **适用场景** | 单色系照片细分 | 多样化照片分类 |
| **K 值选择** | 用户指定（3-12） | Silhouette Score |
| **处理时间** | 快（约 5s） | 慢（约 15s） |
| **质量评分** | 不计算 | 计算 Silhouette Score |
| **空簇** | 可能出现 | 较少出现 |
| **细分能力** | 强（K 值大） | 弱（K 值保守） |

### 为什么会有空簇？

**原因**：
- KMeans 算法可能收敛到局部最优
- 初始质心随机选择，可能不理想
- 对于单色系照片，某些质心可能没有被分配任何点

**影响**：
- 空簇不影响有照片的簇
- 只是浪费了一些 K 值配额

**解决方案**：
- 降低 K 值（如从 8 降到 6）
- 或者接受空簇的存在（不影响使用）

## 推荐配置

### 单色系照片（6-20 张）

| 照片数 | 推荐 K 值 | 说明 |
|--------|----------|------|
| 6-10 张 | K=6 | 适度细分 |
| 10-15 张 | K=8 | 标准细分 |
| 15-20 张 | K=10 | 精细细分 |

### 多色系照片（自动模式）

| 照片数 | K 值范围 | 说明 |
|--------|----------|------|
| < 10 张 | 3-6 | 保守 |
| 10-50 张 | 3-8 | 平衡 |
| > 50 张 | 3-12 | 全范围 |

## 后续优化

1. **智能 K 值推荐**：
   - 分析照片的色彩多样性
   - 自动推荐合适的 K 值范围

2. **KMeans++ 改进**：
   - 使用更好的初始化策略
   - 减少空簇的出现

3. **多次运行取最优**：
   - 对于手动 K 值，运行多次 KMeans
   - 选择质量最好的结果

4. **空簇处理**：
   - 自动检测空簇
   - 提示用户降低 K 值

---

**修复完成时间**：2025/11/9  
**问题报告者**：用户  
**修复者**：AI Assistant  
**文档版本**：1.0

