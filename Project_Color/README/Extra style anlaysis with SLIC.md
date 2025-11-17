下面我给你一套**完整可落地的方案**，从 **数据模型 → 计算流程 → 聚合分析 → 最终给 DeepSeek 的输入 → Prompt 模板**，一次性给全。

这套方案满足你的目标：

* 摄影作品集整体风格分析
* 包含光线、色彩、情绪
* 基于你已有的 Lab / SLIC / 明暗分区 / 主色 / Global Palette
* 可扩展
* 深度可解释
* 输入结构对 LLM（DeepSeek）最友好
* 输出为中文

---

# 🧩 **一、需要新增的数据模型（轻量、结构化）**

你现在已有：

* 单张图的 Lab 分布、明暗分区
* SLIC 区块
* 冷暖分数
* 主色 Top 5 + 名字
* 全局 palette

你缺的是：

## 🔸**A. 单张图中层特征模型**

这会作为“从单张图得到的语义特征”。
用于后续作品集聚合。

```swift
struct ImageFeature {
    // 光线
    var brightness: BrightnessLevel      // low / medium / high
    var contrast: ContrastLevel          // low / medium / high
    var dynamicRange: DynamicRangeLevel  // narrow / medium / wide
    var lightDirection: LightDirection?  // left / right / top / back / etc.
    var shadowRatio: Float               // 0~1
    var highlightRatio: Float            // 0~1

    // 色彩
    var coolWarmScore: Float             // [-1, 1]
    var saturationLevel: SaturationLevel // low/medium/high
    var colorVariety: ColorVarietyLevel  // low/medium/high

    var dominantColors: [NamedColor]     // name + rgb + ratio

    // 情绪（算法自动推）
    var moodTags: [String]
}
```

其中几种枚举类型例如：

```swift
enum BrightnessLevel: String { case low, medium, high }
enum ContrastLevel: String { case low, medium, high }
enum DynamicRangeLevel: String { case narrow, medium, wide }
enum SaturationLevel: String { case low, medium, high }
enum ColorVarietyLevel: String { case low, medium, high }

struct NamedColor {
    var name: String
    var ratio: Float
}
```

### ❗这是关键：

LLM **不适合读原始数值**
它需要你帮它“离散化”。
这就是中层特征模型的意义。

---

## 🔸**B. 作品集（Collection）聚合特征模型**

来自多张 ImageFeature 的汇总结果 → 给 LLM 的最终输入。

```swift
struct CollectionFeature {
    // 光线整体统计
    var brightnessDistribution: BrightnessLevel
    var contrastDistribution: ContrastLevel
    var dynamicRangeDistribution: DynamicRangeLevel
    var lightDirectionStats: [LightDirection: Float]

    // 色彩整体统计
    var meanCoolWarmScore: Float
    var saturationDistribution: SaturationLevel
    var colorVariety: ColorVarietyLevel
    var globalPalette: [NamedColor]  // 你已有

    // 情绪分布
    var aggregatedMoodTags: [String: Float]

    // 标志性标签（算法输出）
    var styleTags: [String]
}
```

---

# 🧮 **二、需要新增的计算（核心逻辑）**

从单张图中提以下东西（你已有数据情况下都能简单算出来）：

---

## 🔹1. 亮度（brightness）

用全局 L_mean：

* < 35 → low
* 35–65 → medium
* > 65 → high

---

## 🔹2. 对比度（contrast）

使用 `L_std` 或 DR（95% - 5%）：

* < 14 → low
* 14–28 → medium
* > 28 → high

---

## 🔹3. 动态范围（DR）

用百分位：

```
DR = L_p95 - L_p05
```

离散化：

* < 30 → narrow
* 30–55 → medium
* > 55 → wide

---

## 🔹4. 光线方向（light direction）

高光区域的质心（centroid）：

* X/Y 与图像中心比较：

  * 左上 = left-top
  * 右上 = right-top
  * 同理其他方向

把 top/bottom 压成一个维度，最终建议用：left / right / back / overhead / front。

---

## 🔹5. 饱和度水平（saturation level）

用 HSL 中 S：

* <0.18 → low
* 0.18–0.35 → medium
* > 0.35 → high

---

## 🔹6. 色彩丰富程度（color variety）

基于主色数量 + 距离差：

* 有效主色 (ratio > 0.12) 小于 2 → low
* 2–4 → medium
* ≥5 → high

---

## 🔹7. 情绪（moodTags）算法（规则即可）

基于亮度 + 对比度 + 冷暖 + 饱和度：

示例：

* 冷 + 低饱和 + 中低亮度 → quiet, lonely
* 暖 + 高亮度 + 高饱和 → happy
* 暖 + 低亮度 → nostalgic
* 冷 + 高对比 → cinematic

你可以拼一些标签。
这是 LLM 最喜欢的结构类型。

---

## 🔹8. 作品集聚合（CollectionFeature）

从 N 张图片的 ImageFeature 得出：

* brightnessDistribution = 众数（或平均等级）
* contrastDistribution = 众数
* dynamicRange = 众数
* lightDirectionStats = 每个方向的比例
* meanCoolWarmScore = 平均冷暖
* saturationDistribution = 众数
* colorVariety = 众数
* globalPalette = 你已有（按全部照片权重整合）
* aggregatedMoodTags = 所有 moodTags 做加权频率
* styleTags = 用简单规则合成，例如：

  * 冷暖偏冷 → “slightly_cool”
  * 饱和度低 → “muted_colors”
  * 冷色占比大 → “blue_green_tone”
  * DR medium → “natural_dynamic_range”

这就是一套完整风格系统。

---

# 🧠 **三、给 DeepSeek 的输入（最终 JSON）**

系统 prompt 用英文（稳定），输出中文。

### 🔧 System Prompt（英文）

```
You are a professional photography critic. 
The user will give you aggregated analysis of a photo collection.

Your tasks:
1. Summarize the overall lighting characteristics (2–3 sentences).
2. Summarize the global color style and palette aesthetics (2–3 sentences).
3. Summarize the emotional atmosphere (2–3 sentences).
4. Provide 5–8 concise Chinese tags describing the photographer's style.
5. Output everything in Chinese.
Important: Analyze the collection as a whole, not individual photos.
Use precise photography terminology and avoid exaggeration.
```

---

### 📦 User Input JSON（你生成的 CollectionFeature）

示例（填你自己的）：

```json
{
  "brightness_distribution": "mostly_low",
  "contrast_distribution": "medium",
  "dynamic_range_distribution": "medium",
  "light_direction_stats": {
    "left": 0.33,
    "right": 0.27,
    "back": 0.18,
    "top": 0.12
  },
  "mean_cool_warm_score": -0.12,
  "saturation_distribution": "low",
  "color_variety": "medium",
  "global_palette": [
    { "name": "soft blue", "ratio": 0.23 },
    { "name": "muted green", "ratio": 0.21 },
    { "name": "warm beige", "ratio": 0.11 }
  ],
  "aggregated_mood_tags": {
    "quiet": 0.32,
    "nostalgic": 0.28,
    "melancholic": 0.16,
    "warm": 0.08
  },
  "style_tags": ["film_like", "muted_colors", "slightly_cool"]
}
```

DeepSeek 输出：

```json
{
  "lighting": "...",
  "color_style": "...",
  "mood": "...",
  "style_keywords": ["...", "...", "..."]
}
```

中文自然输出。

---

# 🟦 **四、你现在拥有的完整方案包括：**

## ✔ 数据模型（ImageFeature + CollectionFeature）

## ✔ 新增必要计算（11 个核心指标）

## ✔ 如何聚合多张图

## ✔ 给 LLM 的最终 JSON

## ✔ 适用 DeepSeek 的 Prompt（英文）

这是一套足够生产级的“摄影风格 AI 分析框架”。

---

如果你愿意，我还可以继续提供：

### 🔸 A. 数值 → 标签的全部阈值表（可直接写进代码）

### 🔸 B. 我帮你将 ImageFeature → CollectionFeature 的 Swift 实现

### 🔸 C. 提供一个 DeepSeek 输出案例（模拟真实结果）

### 🔸 D. 让你 9 张图跑一遍这个系统，现场给你一个“作品集风格总结”

你想先做哪一步？
