

# ✅ 1. 你需要新增的数据结构（Swift）

```swift
struct PatternSignals {
    var hasPattern: Bool
    var patternDescription: String
}

struct CollectionStyleAnalysisInput {
    var dominantColors: [DominantColor]
    var hueDistribution: [Float]
    var saturationDistribution: [Float]
    var lightnessDistribution: [Float]
    var highlightRatio: Float
    var midtoneRatio: Float
    var shadowRatio: Float
    var brightnessStats: (mean: Float, std: Float)
    var contrastStats: (mean: Float)
    var warmCoolScore: Float
    var moodTags: [String]
    var styleTags: [String]

    // 🔥 新增的字段
    var styleConsistencyScore: Float
    var patternSignals: PatternSignals
}
```

你只需要把这 2 个字段加入你最后发给 LLM 的 JSON 里。

---

# ✅ 2. 哪些部分需要新增“计算”？（重要）

你已经有：

* 主色（含占比）
* H/S/L 分布
* 冷暖分值
* 明暗分区
* SLIC 超像素
* 饱和度、亮度统计全部齐了

所以**不用增加大计算量**，只需：

### **（A）计算一致性（style_consistency_score）**

反映“是否可能有风格规律”。

你只需要基于现有数据算4个标准差：

* 色相标准差（Hue Std）
* 饱和度标准差（Sat Std）
* 亮度标准差（Light Std）
* 冷暖波动（WarmCool Variance）

然后映射成一个 0 ~ 1 的分数。

---

# 🎯 Swift 实现（可直接复制）

## **1. 计算各向量的标准差**

```swift
func std(_ arr: [Float]) -> Float {
    guard !arr.isEmpty else { return 0 }
    let mean = arr.reduce(0, +) / Float(arr.count)
    let varSum = arr.map { pow($0 - mean, 2) }.reduce(0, +)
    return sqrt(varSum / Float(arr.count))
}
```

---

## **2. 计算 Style Consistency Score**

```swift
func computeStyleConsistencyScore(
    hueDistribution: [Float],
    saturationDistribution: [Float],
    lightnessDistribution: [Float],
    warmCoolScores: [Float]  // 你已有每张图的冷暖
) -> Float {

    let hueStd = std(hueDistribution)
    let satStd = std(saturationDistribution)
    let lightStd = std(lightnessDistribution)
    let warmCoolStd = std(warmCoolScores)

    // 映射成“越稳定 → 越高分”
    let invHue = 1 - min(hueStd / 0.25, 1)       // Hue 波动 > 0.25 基本就混乱
    let invSat = 1 - min(satStd / 0.20, 1)
    let invLight = 1 - min(lightStd / 0.20, 1)
    let invWarmCool = 1 - min(warmCoolStd / 0.30, 1)

    return max(0, min(1, (invHue + invSat + invLight + invWarmCool) / 4))
}
```

* 值接近 1 → 风格统一
* 值接近 0 → 混乱

---

# ⭐ 3. 计算 pattern_signals（是否有显著规律）

这里只要判断三个关键特征是否“强烈偏向”即可。

```swift
func detectPattern(
    dominantColors: [DominantColor],
    warmCoolScore: Float,
    styleConsistencyScore: Float
) -> PatternSignals {

    // 规则 1：色系占比是否特别集中（主色超过 45%）
    let mainColorDominant = dominantColors.contains { $0.weight > 0.45 }

    // 规则 2：冷暖是否明显偏向
    let strongWarmCool = abs(warmCoolScore) > 0.25  // 可调整

    // 规则 3：风格一致性需达到最低阈值
    let consistent = styleConsistencyScore >= 0.55

    if consistent && (mainColorDominant || strongWarmCool) {
        var desc = ""

        if mainColorDominant {
            if let dc = dominantColors.first(where: { $0.weight > 0.45 }) {
                desc += "主色调集中在 \(dc.colorName)，占比显著偏高；"
            }
        }

        if strongWarmCool {
            desc += warmCoolScore > 0 ? "整体色温偏暖，呈现稳定暖色倾向；" :
                                        "整体色温偏冷，呈现持续冷色倾向；"
        }

        return PatternSignals(hasPattern: true, patternDescription: desc)
    }

    return PatternSignals(hasPattern: false, patternDescription: "")
}
```

—

# ⭐ 4. 在主流程中组装最终 JSON

```swift
let score = computeStyleConsistencyScore(
    hueDistribution: hueValues,
    saturationDistribution: satValues,
    lightnessDistribution: lightValues,
    warmCoolScores: warmCoolScoresPerImage
)

let patterns = detectPattern(
    dominantColors: dominantColors,
    warmCoolScore: globalWarmCoolScore,
    styleConsistencyScore: score
)

let llmInput = CollectionStyleAnalysisInput(
    dominantColors: dominantColors,
    hueDistribution: hueValues,
    saturationDistribution: satValues,
    lightnessDistribution: lightValues,
    highlightRatio: highlight,
    midtoneRatio: midtone,
    shadowRatio: shadow,
    brightnessStats: brightness,
    contrastStats: contrast,
    warmCoolScore: globalWarmCoolScore,
    moodTags: moodTags,
    styleTags: styleTags,
    styleConsistencyScore: score,
    patternSignals: patterns
)
```

然后把 JSON 发给 DeepSeek。
