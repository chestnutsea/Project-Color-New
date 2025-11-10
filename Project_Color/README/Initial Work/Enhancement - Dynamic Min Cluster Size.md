# 增强：动态最小簇大小

## 概述

根据照片数量和分析模式，自动调整最小簇大小（`minClusterSize`），避免在小数量照片时过度删除色系。

## 问题背景

**之前的问题**：
- 用户使用"多彩模式"分析 10 张五颜六色的照片
- K-Means 识别出 3 个色系
- 自适应聚类使用固定的 `minClusterSize = 1`（修复前是 3）
- 但对于小数量照片，即使是 `minClusterSize = 2` 也可能导致色系被删除

**核心矛盾**：
- **小数量照片**（如 10 张）：应该保留所有色系，`minClusterSize = 1`
- **大数量照片**（如 100 张）：
  - **多彩模式**：应该保留更多色系，`minClusterSize = 1`
  - **其他模式**：可以删除小簇，`minClusterSize = 2`

## 解决方案

### 动态计算逻辑

```swift
let dynamicMinClusterSize: Int
if let userMinClusterSize = settings.minClusterSize {
    // 用户手动设置了，直接使用
    dynamicMinClusterSize = userMinClusterSize
} else {
    // 根据照片数量和合并阈值动态计算
    let photoCount = assets.count
    let mergeThreshold = settings.effectiveMergeThreshold
    
    if photoCount <= 20 {
        // 小数量：无论什么模式，都设为 1
        dynamicMinClusterSize = 1
    } else if mergeThreshold <= 10.0 {
        // 大数量 + 多彩模式（严格合并）：设为 1，保留更多色系
        dynamicMinClusterSize = 1
    } else {
        // 大数量 + 其他模式：使用默认值 2
        dynamicMinClusterSize = 2
    }
}
```

### 判断逻辑

| 照片数量 | 合并阈值 | 模式推断 | 最小簇大小 |
|---------|---------|---------|-----------|
| ≤ 20 | 任意 | 小数量 | 1 |
| > 20 | ≤ 10.0 | 多彩模式 | 1 |
| > 20 | > 10.0 | 其他模式 | 2 |

### 模式识别

**如何判断是"多彩模式"？**
- 通过 `mergeThreshold <= 10.0` 来识别
- 多彩模式的特征：严格合并（ΔE = 10.0）
- 单色系模式：更严格（ΔE = 6.0）
- 精细分类：严格（ΔE = 8.0）
- 平衡分类：适中（ΔE = 12.0）
- 简洁分类：宽松（ΔE = 18.0）

## 预设配置更新

### 更新后的预设

| 预设 | 合并阈值 | 最小簇大小 | 说明 |
|-----|---------|-----------|------|
| **平衡分类** | 12.0 | `nil`（动态） | 小数量 → 1，大数量 → 2 |
| **多彩模式** | 10.0 | `nil`（动态） | 小数量 → 1，大数量 → 1 |
| **单色系细分** | 6.0 | `nil`（动态） | 小数量 → 1，大数量 → 1 |
| **精细分类** | 8.0 | `nil`（动态） | 小数量 → 1，大数量 → 1 |
| **简洁分类** | 18.0 | `3`（固定） | 始终为 3，强制简化 |

**关键点**：
- ✅ 只有"简洁分类"使用固定值 `minClusterSize = 3`
- ✅ 其他所有预设都使用 `minClusterSize = nil`，触发动态计算
- ✅ 用户可以手动设置 `minClusterSize`，会覆盖动态计算

## 使用场景

### 场景 1：10 张五颜六色的照片

**之前（固定 minClusterSize = 1）**：
- K-Means: 3 个色系
- 自适应聚类: 可能删除小簇
- 结果: 2 个色系 ❌

**现在（动态 minClusterSize = 1）**：
- K-Means: 3 个色系
- 自适应聚类: 保留所有簇（photoCount ≤ 20）
- 结果: 3 个色系 ✅

### 场景 2：100 张照片，使用"多彩模式"

**配置**：
- 合并阈值: 10.0
- 照片数量: 100

**动态计算**：
- photoCount > 20 ✅
- mergeThreshold <= 10.0 ✅
- → `minClusterSize = 1`

**效果**：
- 保留更多色系
- 适合颜色丰富的照片集

### 场景 3：100 张照片，使用"平衡分类"

**配置**：
- 合并阈值: 12.0
- 照片数量: 100

**动态计算**：
- photoCount > 20 ✅
- mergeThreshold > 10.0 ✅
- → `minClusterSize = 2`

**效果**：
- 删除只有 1 张照片的小簇
- 保留主要色系

### 场景 4：100 张照片，使用"简洁分类"

**配置**：
- 合并阈值: 18.0
- 照片数量: 100
- **固定** `minClusterSize = 3`

**效果**：
- 删除只有 1-2 张照片的小簇
- 强制简化，只保留主要色系
- 不受动态计算影响

### 场景 5：用户手动设置 minClusterSize

**配置**：
- 用户手动设置 `minClusterSize = 5`
- 照片数量: 10

**效果**：
- 使用用户设置的值 5
- 不使用动态计算
- 用户设置优先级最高

## 调试输出

**新增调试信息**：
```
📊 自适应聚类配置:
   - 照片数量: 10
   - 合并阈值 ΔE: 10.0
   - 最小簇大小: 1 (动态)
   - 名称相似性: 关闭
```

**说明**：
- `(动态)`: 使用动态计算的值
- `(手动)`: 使用用户手动设置的值

## 优势

### 1. 自适应

- ✅ 根据照片数量自动调整
- ✅ 根据分析模式自动调整
- ✅ 无需用户手动配置

### 2. 智能

- ✅ 小数量照片：保留所有色系
- ✅ 大数量 + 多彩模式：保留更多色系
- ✅ 大数量 + 其他模式：删除小簇

### 3. 灵活

- ✅ 用户可以手动覆盖
- ✅ "简洁分类"保留固定值
- ✅ 其他预设使用动态计算

## 技术细节

### 实现位置

**文件**: `SimpleAnalysisPipeline.swift`

**位置**: 自适应聚类配置阶段（Phase 5）

**代码**:
```swift
// Phase 5: 使用用户设置或默认配置
// 动态计算最小簇大小（如果用户没有手动设置）
let dynamicMinClusterSize: Int
if let userMinClusterSize = settings.minClusterSize {
    // 用户手动设置了，直接使用
    dynamicMinClusterSize = userMinClusterSize
} else {
    // 根据照片数量和合并阈值动态计算
    let photoCount = assets.count
    let mergeThreshold = settings.effectiveMergeThreshold
    
    if photoCount <= 20 {
        // 小数量：无论什么模式，都设为 1
        dynamicMinClusterSize = 1
    } else if mergeThreshold <= 10.0 {
        // 大数量 + 多彩模式（严格合并）：设为 1，保留更多色系
        dynamicMinClusterSize = 1
    } else {
        // 大数量 + 其他模式：使用默认值 2
        dynamicMinClusterSize = 2
    }
}
```

### 阈值选择

**为什么选择 20 张作为"小数量"阈值？**
- 10 张以下：非常小，必须保留所有簇
- 10-20 张：较小，应该保留所有簇
- 20 张以上：足够大，可以删除小簇

**为什么选择 10.0 作为"多彩模式"阈值？**
- 多彩模式: ΔE = 10.0
- 单色系模式: ΔE = 6.0
- 精细分类: ΔE = 8.0
- 平衡分类: ΔE = 12.0
- 简洁分类: ΔE = 18.0

使用 10.0 可以准确识别"多彩模式"和"精细分类"。

## 用户体验

### 对用户透明

- ✅ 用户无需了解这个机制
- ✅ 自动工作，无需配置
- ✅ 调试输出显示"(动态)"标记

### 可控性

- ✅ 用户可以在设置中手动指定 `minClusterSize`
- ✅ 手动设置会覆盖动态计算
- ✅ 调试输出显示"(手动)"标记

### 一致性

- ✅ 小数量照片：总是保留所有色系
- ✅ 大数量照片：根据模式智能调整
- ✅ 简洁分类：总是强制简化

## 后续优化

### 1. 更精细的阈值

```swift
if photoCount <= 10 {
    dynamicMinClusterSize = 1
} else if photoCount <= 30 {
    dynamicMinClusterSize = max(1, photoCount / 20)  // 10-30张 → 1
} else if mergeThreshold <= 10.0 {
    dynamicMinClusterSize = 1
} else {
    dynamicMinClusterSize = max(2, photoCount / 50)  // 50张 → 2, 100张 → 2, 200张 → 4
}
```

### 2. 基于色彩多样性

```swift
let colorDiversity = calculateColorDiversity(allMainColorsLAB)
if colorDiversity > 0.8 {
    // 颜色非常多样，保留更多簇
    dynamicMinClusterSize = 1
} else if colorDiversity < 0.3 {
    // 颜色单一，可以删除小簇
    dynamicMinClusterSize = 3
}
```

### 3. 基于 K 值

```swift
if optimalK >= 8 {
    // K 值很大，说明颜色多样，保留小簇
    dynamicMinClusterSize = 1
} else if optimalK <= 3 {
    // K 值很小，说明颜色单一，可以删除小簇
    dynamicMinClusterSize = 2
}
```

## 总结

**核心思想**：
> 最小簇大小应该根据照片数量和分析模式动态调整，而不是固定值。

**关键规则**：
1. **小数量照片**（≤ 20 张）→ `minClusterSize = 1`
2. **大数量 + 多彩模式**（> 20 张，ΔE ≤ 10）→ `minClusterSize = 1`
3. **大数量 + 其他模式**（> 20 张，ΔE > 10）→ `minClusterSize = 2`
4. **用户手动设置** → 优先使用用户设置
5. **简洁分类** → 固定为 3，不使用动态计算

**效果**：
- ✅ 10 张五颜六色的照片 → 保留所有色系
- ✅ 100 张旅行照片（多彩模式）→ 保留更多色系
- ✅ 100 张日常照片（平衡分类）→ 删除小簇
- ✅ 用户可以手动覆盖

---

**实施完成时间**：2025/11/9  
**实施者**：AI Assistant  
**文档版本**：1.0

