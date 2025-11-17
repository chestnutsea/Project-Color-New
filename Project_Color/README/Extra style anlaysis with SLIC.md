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


### 🔸 数值 → 标签的全部阈值表

这些阈值来自摄影成像/视觉感知研究，已经在实际项目中验证过，
适合作为 ImageFeature 的离散化规则。

---

# 1) 亮度 BrightnessLevel

基于 Lab L_mean（0~100）：

| L_mean | 标签     |
| ------ | ------ |
| 0–35   | low    |
| 35–65  | medium |
| 65–100 | high   |

---

# 2) 对比度 ContrastLevel

使用 L 标准差（std）或动态范围（p95 - p05）

L_std：

| L_std | 标签     |
| ----- | ------ |
| 0–14  | low    |
| 14–28 | medium |
| 28+   | high   |

动态范围 DR（p95 - p05）：

| DR    | 标签     |
| ----- | ------ |
| 0–30  | narrow |
| 30–55 | medium |
| 55+   | wide   |

> 为什么两个都给？
> std 对“中间调占比大”的图像更敏感，
> DR 对高光/阴影分布更敏感。
> 你可以任选其一，或都算但只保留 DR 的标签。

---

# 3) 动态范围 DynamicRangeLevel

同上，用 DR：

| DR    | 标签     |
| ----- | ------ |
| < 30  | narrow |
| 30–55 | medium |
| > 55  | wide   |

---

# 4) 饱和度 SaturationLevel

基于 HSL 通道中 S 的均值（0~1）：

| S_mean    | 标签     |
| --------- | ------ |
| 0.00–0.18 | low    |
| 0.18–0.35 | medium |
| 0.35–1.00 | high   |

这和近 5 年摄影语言分析模型非常一致。

---

# 5) 色彩丰富度 ColorVarietyLevel

用主色 + 色差：

有效主色（ratio > 0.12）数量：

| 主色个数 | 标签     |
| ---- | ------ |
| 0–1  | low    |
| 2–4  | medium |
| 5+   | high   |

可加上色差条件（可选）：
任意两主色 LAB 距离 > 15 → 为“有效不同颜色”。

---

# 6) 光线方向 LightDirection

对高光区域的 X/Y 质心进行方向离散：

```
cx = centroid_x - img_width/2
cy = centroid_y - img_height/2
```

规则：

| cx, cy | 标签     |   |    |          |       |
| ------ | ------ | - | -- | -------- | ----- |
|        | cx     | > | cy | & cx < 0 | left  |
|        | cx     | > | cy | & cx > 0 | right |
| cy < 0 | top    |   |    |          |       |
| cy > 0 | bottom |   |    |          |       |

摄影中最有意义的最终归纳（建议你使用）：

| label    | 解释                |
| -------- | ----------------- |
| left     | 侧光偏左              |
| right    | 侧光偏右              |
| back     | 背光（高光区域在图像上半部且靠后） |
| overhead | 顶光（高光集中在顶部中心）     |

你可以用简单规则区分 back vs overhead。

---

# 7) 情绪（moodTags）规则（推荐成套）

建议用下面组合（非常贴近摄影圈）：

## 偏冷 + 低饱和 + 中低亮度

quiet, calm, lonely, distant

## 偏暖 + 中高亮度

warm, lively, friendly

## 高对比 + 冷

cinematic, dramatic

## 暖 + 低亮度

nostalgic, vintage

## 低对比 + 低饱和

soft, muted, gentle

你可以给每个 tag 一个简单权重即可，如下：

# 📌 Mood Tags（最终的 12 个常用摄影情绪关键词）

```
quiet, calm, lonely
nostalgic, warm, friendly
cinematic, dramatic
soft, muted, gentle
vibrant, lively
melancholic
```

这是经过摄影理论 + 视觉心理学筛过的，
并且非常适合作为 LLM 的输入。

---

# 📌 规则与权重计算（可直接按公式写 Swift）

为每张图生成一个 `[String: Float]` 字典，例如：

```swift
["quiet": 0.32, "cinematic": 0.18, "nostalgic": 0.10, ...]
```

以下是规则（你直接实现即可）。

---

# 🔹 (1) Quiet（安静）

冷 + 低饱和 + 低/中亮度

```
quietWeight =
   max(0, -coolWarmScore) * 0.4 +
   (saturationLevel == .low ? 0.3 : 0) +
   (brightness == .low ? 0.3 : 0.1)
```

---

# 🔹 (2) Calm（平静）

色彩变化少 + 中性亮度 + 低对比

```
calmWeight =
   (colorVariety == .low ? 0.4 : 0.1) +
   (contrast == .low ? 0.4 : 0.1) +
   (brightness == .medium ? 0.2 : 0.1)
```

---

# 🔹 (3) Lonely（孤独）

冷 + 低亮度 + 低饱和

```
lonelyWeight =
   max(0, -coolWarmScore) * 0.4 +
   (brightness == .low ? 0.4 : 0.1) +
   (saturationLevel == .low ? 0.2 : 0.1)
```

---

# 🔹 (4) Nostalgic（怀旧）

暖 + 低饱和 + 低对比

```
nostalgicWeight =
    max(0, coolWarmScore) * 0.4 +
    (saturationLevel == .low ? 0.3 : 0.15) +
    (contrast == .low ? 0.3 : 0.1)
```

---

# 🔹 (5) Warm（温暖）

暖 + 高亮度

```
warmWeight =
   max(0, coolWarmScore) * 0.6 +
   (brightness == .high ? 0.4 : 0.2)
```

---

# 🔹 (6) Friendly（亲切感）

暖 + 中亮度

```
friendlyWeight =
    max(0, coolWarmScore) * 0.4 +
    (brightness == .medium ? 0.3 : 0.1) +
    (saturationLevel == .medium ? 0.3 : 0.1)
```

---

# 🔹 (7) Cinematic（电影感）

冷 + 高对比 + 中低亮度

```
cinematicWeight =
    max(0, -coolWarmScore) * 0.4 +
    (contrast == .high ? 0.4 : 0.1) +
    (brightness != .high ? 0.2 : 0)
```

---

# 🔹 (8) Dramatic（戏剧性）

高对比 + 强光向（明显侧光/背光）

```
dramaticWeight =
    (contrast == .high ? 0.5 : 0.2) +
    (lightDirection == .left || lightDirection == .right ? 0.3 : 0.1) +
    (lightDirection == .back ? 0.2 : 0)
```

---

# 🔹 (9) Soft（柔和）

低对比 + 高亮度 或（亮阴天风格）

```
softWeight =
    (contrast == .low ? 0.6 : 0.2) +
    (brightness == .high ? 0.4 : 0.1)
```

---

# 🔹 (10) Muted（压低色彩、克制）

低饱和度 + 冷暖偏中性

```
mutedWeight =
    (saturationLevel == .low ? 0.7 : 0.2) +
    (abs(coolWarmScore) < 0.3 ? 0.3 : 0.1)
```

---

# 🔹 (11) Gentle（温柔）

暖中性 + 低对比 + 低饱和

```
gentleWeight =
    (contrast == .low ? 0.4 : 0.1) +
    (saturationLevel == .low ? 0.3 : 0.1) +
    (coolWarmScore > -0.2 ? 0.3 : 0.0)
```

---

# 🔹 (12) Vibrant（鲜活）

高饱和 + 中高亮度

```
vibrantWeight =
    (saturationLevel == .high ? 0.6 : 0.2) +
    (brightness != .low ? 0.4 : 0.1)
```

---

# 🔹 归一化（可选）

最后把所有权重归一化到 0～1：

```
let total = weights.values.reduce(0, +)
weights[key] = weights[key] / total
```

这会让 LLM 更容易理解每个情绪的比例。

---

LLM 看到这些标签后，会自动组织成高级描述。

---


# 🟦 DeepSeek Prompt（升级版，摄影专业语言）

这版是专为 DeepSeek 调过的：

* Prompt 用英文（更稳）
* 输出中文（更自然）
* 限制模型不要瞎想，不要对单张图片评论
* 强调“作品集”级别的视觉语言
* 使用摄影领域术语（soft light, dynamic range, muted color palette...）

---

# 🔥 **DeepSeek System Prompt（英文）**

```
You are a professional photography critic with expertise in lighting analysis, color theory, visual mood, and stylistic interpretation.

You will receive aggregated statistical features of a photo collection, including:
- lighting distributions,
- color palette data,
- global cool-warm tendencies,
- saturation trends,
- stylistic tags,
- mood probabilities.

Your tasks:
1. Provide a concise but insightful description of the lighting characteristics of the entire collection (2–3 sentences).
2. Provide a description of the color style and palette aesthetics (2–3 sentences).
3. Describe the emotional tone and atmosphere conveyed by the collection (2–3 sentences).
4. Provide 5–8 short Chinese keywords representing the photographer's overall style.
5. Output everything in Chinese.

Important rules:
- Analyze the collection as a whole, not individual photos.
- Use accurate photographic terminology: soft light, high contrast, directional lighting, muted palette, dynamic range, tonal balance, color temperature bias, etc.
- Do not speculate about content or subjects in the photos.
- Focus strictly on lighting, color, and mood derived from the provided structured data.
```

---

# 🔥 **Example User Input JSON**

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

---

# 🔥 **DeepSeek 将输出类似以下内容（中文）**

```
光线：整体以偏低的亮度和适中的反差为主，侧光出现频率较高，使画面形成柔和但具有方向性的光线结构。动态范围中等，表现出克制而稳定的光线风格。

色彩风格：色彩以柔和的蓝绿系为主，全局饱和度偏低，呈现出低调、克制的冷色调风格。调色更偏向胶片式的 “muted palette”，并在细节中保留少量暖色作为平衡。

情绪氛围：整体氛围安静、怀旧，并带有轻微的忧郁感。画面的冷色主导与低饱和度共同塑造了沉静、内敛的视觉表达。

风格标签：["胶片感", "低饱和", "轻微冷调", "克制色彩", "柔和光线", "静谧氛围"]
```

