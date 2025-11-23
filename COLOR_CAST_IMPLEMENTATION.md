# 色偏分析（Color Cast）实现更新

## 更新日期
2025-11-22

## 概述
将色偏分析算法从单一区域计算升级为**高光区域**和**阴影区域**分别计算，提供更精确的色偏信息。

---

## 1. 算法改进

### 旧算法
- 将高光和阴影区域混合在一起计算
- 只输出一组色偏数据（aMean, bMean, cast, hue）

### 新算法
- **分别计算**高光区域和阴影区域的色偏
- 使用 RMS 对比度自动划分高光/阴影阈值
- 输出两组独立的色偏数据：
  - **高光区域**: `highlightAMean`, `highlightBMean`, `highlightCast`, `highlightHueDegrees`
  - **阴影区域**: `shadowAMean`, `shadowBMean`, `shadowCast`, `shadowHueDegrees`
- 保留兼容性字段（使用平均值）

### 核心步骤

```swift
// 1. 分离 L, a, b 通道
var Ls = [Float](repeating: 0, count: pixelCount)
var As = [Float](repeating: 0, count: pixelCount)
var Bs = [Float](repeating: 0, count: pixelCount)

// 2. 计算 RMS 对比度
let Lmean = Ls.reduce(0, +) / Float(pixelCount)
let variance = Ls.map { ($0 - Lmean) * ($0 - Lmean) }.reduce(0, +) / Float(pixelCount)
let rms = sqrt(variance)

// 3. 自动划分阈值
let shadowT = Lmean - rms
let highlightT = Lmean + rms

// 4. 分别统计高光和阴影区域（只保留低彩度像素 C < 15）
for i in 0..<pixelCount {
    let L = Ls[i]
    let a = As[i]
    let b = Bs[i]
    
    let C = a * a + b * b
    if C > 225 { continue }  // 跳过高饱和像素
    
    if L < shadowT {
        shadowASum += a
        shadowBSum += b
        shadowCount += 1
    }
    
    if L > highlightT {
        highlightASum += a
        highlightBSum += b
        highlightCount += 1
    }
}

// 5. 计算平均值和色偏强度
let shadowCast = sqrt(shadowAMean * shadowAMean + shadowBMean * shadowBMean)
let highlightCast = sqrt(highlightAMean * highlightAMean + highlightBMean * highlightBMean)

// 6. 计算色相角度
func computeHue(a: Float, b: Float) -> Float {
    let h = atan2(b, a) * 180 / .pi
    return h >= 0 ? h : h + 360
}
```

---

## 2. 数据结构更新

### `ColorCastResult` (AnalysisModels.swift)

```swift
struct ColorCastResult {
    let rms: Float              // RMS 对比度
    
    // 高光区域色偏
    let highlightAMean: Float   // 高光区域 Lab a 通道均值
    let highlightBMean: Float   // 高光区域 Lab b 通道均值
    let highlightCast: Float    // 高光区域偏色强度
    let highlightHueDegrees: Float  // 高光区域色偏方向（0-360°）
    
    // 阴影区域色偏
    let shadowAMean: Float      // 阴影区域 Lab a 通道均值
    let shadowBMean: Float      // 阴影区域 Lab b 通道均值
    let shadowCast: Float       // 阴影区域偏色强度
    let shadowHueDegrees: Float // 阴影区域色偏方向（0-360°）
    
    // 兼容性字段（计算属性，使用平均值）
    var aMean: Float {
        (highlightAMean + shadowAMean) / 2.0
    }
    var bMean: Float {
        (highlightBMean + shadowBMean) / 2.0
    }
    var cast: Float {
        (highlightCast + shadowCast) / 2.0
    }
    var hueAngleDegrees: Float {
        let avgA = aMean
        let avgB = bMean
        let hue = atan2(avgB, avgA) * 180.0 / Float.pi
        return hue >= 0 ? hue : hue + 360
    }
}
```

---

## 3. Core Data 更新

### PhotoAnalysisEntity 新增字段

```xml
<!-- 高光区域色偏 -->
<attribute name="colorCastHighlightAMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastHighlightBMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastHighlightCast" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastHighlightHue" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>

<!-- 阴影区域色偏 -->
<attribute name="colorCastShadowAMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastShadowBMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastShadowCast" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastShadowHue" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>

<!-- 兼容性字段（保留） -->
<attribute name="colorCastAMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastBMean" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastStrength" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="colorCastHue" optional="YES" attributeType="Float" defaultValueString="0" usesScalarValueType="YES"/>
```

---

## 4. 保存逻辑更新 (CoreDataManager.swift)

```swift
// 保存色偏分析数据（新版本：分别保存高光和阴影区域）
if let colorCast = warmCoolScore.colorCastResult {
    photoAnalysis.colorCastRMS = colorCast.rms
    
    // 高光区域色偏
    photoAnalysis.colorCastHighlightAMean = colorCast.highlightAMean
    photoAnalysis.colorCastHighlightBMean = colorCast.highlightBMean
    photoAnalysis.colorCastHighlightCast = colorCast.highlightCast
    photoAnalysis.colorCastHighlightHue = colorCast.highlightHueDegrees
    
    // 阴影区域色偏
    photoAnalysis.colorCastShadowAMean = colorCast.shadowAMean
    photoAnalysis.colorCastShadowBMean = colorCast.shadowBMean
    photoAnalysis.colorCastShadowCast = colorCast.shadowCast
    photoAnalysis.colorCastShadowHue = colorCast.shadowHueDegrees
    
    // 兼容性字段（平均值）
    photoAnalysis.colorCastAMean = colorCast.aMean
    photoAnalysis.colorCastBMean = colorCast.bMean
    photoAnalysis.colorCastStrength = colorCast.cast
    photoAnalysis.colorCastHue = colorCast.hueAngleDegrees
}
```

---

## 5. 调试输出示例

```
🎨 色偏分析:
   RMS 对比度: 25.43
   ━━ 高光区域 ━━
   a*: -2.15, b*: 5.32
   偏色强度: 5.75
   色偏方向: 112.1°
   ━━ 阴影区域 ━━
   a*: 1.83, b*: -3.21
   偏色强度: 3.69
   色偏方向: 299.7°
   ━━ 平均值（兼容）━━
   a*: -0.16, b*: 1.06
   偏色强度: 4.72
   色偏方向: 98.5°
```

---

## 6. 优势

1. **更精确的色偏分析**
   - 高光和阴影分别计算，避免相互抵消
   - 可以检测到更复杂的色偏模式（如蓝色阴影 + 黄色高光）

2. **向后兼容**
   - 保留旧的字段作为计算属性
   - 现有代码无需修改即可继续使用

3. **更丰富的信息**
   - 可以用于更高级的色彩校正
   - 可以识别典型的色偏模式（如日光白平衡偏差）

---

## 7. 使用场景

### 场景 1: 检测白平衡偏差
```swift
if let cast = colorCastResult {
    if cast.shadowCast > 5 && cast.highlightCast > 5 {
        if abs(cast.shadowHueDegrees - cast.highlightHueDegrees) > 90 {
            print("⚠️ 检测到明显的色温偏差")
        }
    }
}
```

### 场景 2: 识别暖色调日落
```swift
if let cast = colorCastResult {
    // 高光偏暖（黄-橙色），阴影偏冷（蓝色）
    if cast.highlightHueDegrees > 30 && cast.highlightHueDegrees < 90 &&
       cast.shadowHueDegrees > 200 && cast.shadowHueDegrees < 260 {
        print("🌅 典型的日落色调")
    }
}
```

### 场景 3: 检测蓝色阴影
```swift
if let cast = colorCastResult {
    if cast.shadowCast > 3 && 
       cast.shadowHueDegrees > 200 && cast.shadowHueDegrees < 260 {
        print("❄️ 阴影区域偏蓝（可能是天空光影响）")
    }
}
```

---

## 8. 文件清单

### 修改的文件
1. ✅ `Project_Color/Models/AnalysisModels.swift`
   - 更新 `ColorCastResult` 结构

2. ✅ `Project_Color/Services/ColorAnalysis/WarmCoolScoreCalculator.swift`
   - 更新 `analyzeColorCast()` 函数
   - 更新调试输出

3. ✅ `Project_Color/Persistence/CoreDataManager.swift`
   - 更新色偏数据保存逻辑

4. ✅ `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`
   - 添加高光和阴影区域的色偏字段
   - 保留兼容性字段

---

## 9. 测试建议

1. **测试不同类型的照片**
   - 日落照片（暖色高光 + 冷色阴影）
   - 室内照片（可能有色温偏差）
   - 阴天照片（整体偏蓝）
   - 夜景照片（人工光源色偏）

2. **验证数据保存**
   - 确认 Core Data 正确保存所有字段
   - 验证兼容性字段的计算正确

3. **性能测试**
   - 确认算法性能没有明显下降
   - 验证内存使用正常

---

## 10. 后续优化方向

1. **色偏校正建议**
   - 基于高光/阴影色偏，生成自动校正建议

2. **色偏模式识别**
   - 识别常见的色偏模式（日光、钨丝灯、荧光灯等）

3. **UI 可视化**
   - 在色轮上显示高光和阴影的色偏方向
   - 提供色偏强度的可视化指示

---

## 完成 ✅

所有代码修改已完成，等待 Xcode 编译验证。
