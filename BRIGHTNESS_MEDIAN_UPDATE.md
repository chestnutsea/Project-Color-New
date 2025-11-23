# 明度计算更新：平均数改为中位数

## 📅 更新日期
2025年11月23日

## ✅ 更新状态
**已完成** - 所有相关代码和文档已更新

---

## 📝 更新内容

### 1. 数据模型更新

**文件**: `Project_Color/Models/AnalysisModels.swift`

- ✅ 重命名 `GlobalColorStatistics.averageLightness` → `medianLightness`
- 说明：全局色彩统计中的明度值现在使用中位数而非平均数

### 2. 统计计算器更新

**文件**: `Project_Color/Services/ColorAnalysis/ColorStatisticsCalculator.swift`

修改内容：
- ✅ 在 `calculateGlobalStatistics()` 方法中，明度收集不再乘以权重
- ✅ 使用新增的 `median()` 方法计算明度中位数
- ✅ 新增 `median(values:)` 私有方法，用于计算中位数

```swift
/// 计算中位数
private func median(values: [Float]) -> Float {
    guard !values.isEmpty else { return 0 }
    
    let sorted = values.sorted()
    let count = sorted.count
    
    if count % 2 == 0 {
        // 偶数个元素，取中间两个的平均值
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
    } else {
        // 奇数个元素，取中间的
        return sorted[count / 2]
    }
}
```

### 3. 散点图明度计算更新

**文件**: `Project_Color/Views/AnalysisResultView.swift`

修改内容：
- ✅ 在 `computeScatterPoints()` 方法中，单张照片的明度计算改为中位数
- ✅ 收集所有主色的明度值到数组
- ✅ 对明度值排序后取中位数

**修改前**：
```swift
var weightedBrightness: Float = 0
// ... 循环中累加
weightedBrightness += Float(brightness) * weight
// ... 最后计算平均
let bri = CGFloat(weightedBrightness / totalWeight) * 255.0
```

**修改后**：
```swift
var brightnessValues: [Float] = []
// ... 循环中收集
brightnessValues.append(Float(brightness))
// ... 最后计算中位数
let sortedBrightness = brightnessValues.sorted()
let medianBrightness: Float
if sortedBrightness.count % 2 == 0 {
    medianBrightness = (sortedBrightness[sortedBrightness.count / 2 - 1] + sortedBrightness[sortedBrightness.count / 2]) / 2.0
} else {
    medianBrightness = sortedBrightness[sortedBrightness.count / 2]
}
let bri = CGFloat(medianBrightness) * 255.0
```

### 4. 文档更新

**文件**: `Project_Color/README/Core Data Structure.md`

- ✅ 更新 `avgLightness` 字段说明：从"平均明度"改为"中位明度"

---

## 🎯 影响范围

### 受影响的功能

1. **全局色彩统计**
   - `GlobalColorStatistics.medianLightness` 现在返回所有照片明度的中位数
   - 影响整体影调倾向的判断（高调/中调/低调）

2. **散点图显示**
   - `SaturationBrightnessScatterView` 中每个点的 Y 轴坐标（明度）
   - 现在使用单张照片主色明度的中位数，而非加权平均

### 不受影响的功能

1. **亮度 CDF（累积分布函数）**
   - `PhotoColorInfo.brightnessCDF` 保持不变
   - 仍然是基于所有像素的累积分布

2. **用户偏好统计**
   - `UserPreferenceViewModel` 中的"平均明度"保持不变
   - 用于用户偏好分析，应该使用平均值

3. **色偏分析**
   - `WarmCoolScoreCalculator` 中的"平均亮度"保持不变
   - 用于色偏分析的统计值，应该使用平均值

---

## 🔍 技术说明

### 为什么使用中位数？

1. **抗干扰性**：中位数对极端值不敏感，更能代表照片的"典型"明度
2. **视觉一致性**：在明度分布不均匀时，中位数更接近视觉感知的中心
3. **统计稳健性**：避免少数极亮或极暗的主色影响整体评估

### 中位数 vs 平均数

| 特性 | 平均数 | 中位数 |
|------|--------|--------|
| 计算方式 | 所有值相加除以数量 | 排序后取中间值 |
| 受极端值影响 | 是 | 否 |
| 计算复杂度 | O(n) | O(n log n) |
| 适用场景 | 数据分布均匀 | 数据有异常值 |

---

## ✅ 测试建议

1. **清空历史数据**
   - 用户需要清空旧的分析结果，因为旧数据使用的是平均值
   - 重新分析照片以获得基于中位数的新结果

2. **验证散点图**
   - 检查 `SaturationBrightnessScatterView` 中点的位置是否合理
   - 对比修改前后的散点图分布

3. **验证全局统计**
   - 检查 `GlobalColorStatistics.medianLightness` 的值
   - 确认整体影调倾向（高调/中调/低调）的判断是否合理

---

## 📚 相关文件

- `Project_Color/Models/AnalysisModels.swift`
- `Project_Color/Services/ColorAnalysis/ColorStatisticsCalculator.swift`
- `Project_Color/Views/AnalysisResultView.swift`
- `Project_Color/Views/SaturationBrightnessScatterView.swift`
- `Project_Color/README/Core Data Structure.md`

---

## 🎉 完成状态

- ✅ 数据模型更新
- ✅ 统计计算更新
- ✅ 散点图计算更新
- ✅ 文档更新
- ✅ 代码注释更新

**所有修改已完成，可以进行测试。**

