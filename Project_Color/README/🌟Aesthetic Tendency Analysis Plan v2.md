//
//  Aesthetic Tendency Analysis.md
//  Project_Color
//
//  Created by Linya Huang on 2025/11/19.
//

# 审美倾向分析系统实现计划（自动模式判断版）

## 核心目标

构建一个智能的审美倾向分析系统，能够：

1. 自动排除截屏和文档类照片
2. 基于 Vision 识别结果智能匹配场景
3. 过滤环境固有色彩，提取用户审美偏移
4. **自动判断分析模式**（基于 S/V/C 三指标）
5. 生成跨场景/场景内的审美倾向描述

## 自动模式判断逻辑

系统通过 **(S, V, C)** 三个指标自动决定分析模式：

| 指标 | 含义 | 计算方法 |

|------|------|----------|

| **S** | 场景数量 | 统计不同场景类型（语义识别） |

| **V** | 偏移稳定性 | 计算偏移向量的标准差 |

| **C** | 主体类别数 | 统计主体类型（人物/街景/物件等） |

### 模式判定规则

| 模式 | 条件 | 系统行为 |

|------|------|----------|

| **组图模式** | S=1 且 C≤2 且 V稳定 | 强化场景内重复特征（如街拍暗部细节） |

| **语言风格匹配** | S=1 且 C=1 | 使用专业术语：街拍=城市肌理 / 人像=肤色情感 |

| **混合模式** | S≥2 或 C≥3 | 严格执行主体色域二次过滤、形成跨主题偏移向量 |

| **跳变审美型** | V极不稳定 且 S≥3 | 输出人格标签：审美跳变型 / 多主题型 |

### 阈值定义

- S 分类：1 / 2-3（弱混合）/ ≥4（强混合）
- V 稳定性：标准差 < 0.15 为稳定，> 0.3 为极不稳定
- C 分类：1 / 2 / ≥3

## 实现步骤

### 1. 扩展数据模型

**文件**: `Project_Color/Models/AnalysisModels.swift`

添加以下新结构：

```swift
// 分析模式（自动判断）
enum AnalysisMode: String, Codable {
    case series = "组图模式"
    case mixed = "混合模式"
    case jumping = "跳变审美型"
}

// 模式判断指标
struct ModeDetectionMetrics: Codable {
    var sceneCount: Int              // S: 场景数量
    var offsetStability: Float       // V: 偏移稳定性（标准差）
    var subjectCategoryCount: Int    // C: 主体类别数
    
    var sceneNames: [String]         // 场景名称列表
    var subjectCategories: [String]  // 主体类别列表
    
    // 判断依据说明
    var detectionReason: String
}

// 场景匹配结果
struct SceneMatchResult: Codable {
    var sceneName: String
    var score: Float
    var confidence: Float
    var baseline: SceneBaseline
    var isMixed: Bool                // 是否为混合场景
    var mixedScenes: [String]?       // 混合场景列表
}

// 场景基准参数
struct SceneBaseline: Codable {
    var colorTemp: (min: Float, max: Float)
    var brightness: (min: Float, max: Float)
    var contrast: (min: Float, max: Float)
    var saturation: (min: Float, max: Float)
    var shadowRatio: (min: Float, max: Float)
    var highlightRatio: (min: Float, max: Float)
}

// 审美偏移向量（8维）
struct AestheticOffset: Codable {
    var brightnessOffset: Float      // 亮度偏移
    var contrastOffset: Float        // 对比度偏移
    var warmCoolOffset: Float        // 冷暖偏移
    var saturationOffset: Float      // 饱和偏移
    var hueDistribution: [Float]     // 色相偏移（分段）
    var shadowRetain: Float          // 暗部保留程度
    var highlightCompress: Float     // 高光压缩
    var colorBalanceOffset: SIMD3<Float>  // RGB 均衡偏移
}

// 审美倾向
struct AestheticTendency: Codable {
    // 跨场景核心审美（稳定出现的偏移）
    var crossSceneCore: [String: Float]
    
    // 场景内风格偏好
    var sceneSpecificStyles: [String: [String: Float]]
    
    // 人格类型
    var personalityType: String      // "稳定型" / "审美跳变型" / "多主题型"
    var personalityDescription: String
}
```

在 `PhotoColorInfo` 中添加：

```swift
var sceneMatch: SceneMatchResult?
var aestheticOffset: AestheticOffset?
var isExcluded: Bool = false
var subjectCategories: [String] = []  // 主体类别
```

在 `AnalysisResult` 中添加：

```swift
@Published var aestheticTendency: AestheticTendency? = nil
@Published var excludedPhotoCount: Int = 0
@Published var detectedMode: AnalysisMode? = nil
@Published var modeDetectionMetrics: ModeDetectionMetrics? = nil
```

### 2. 创建场景匹配服务

**新文件**: `Project_Color/Services/Vision/SceneMatcher.swift`

```swift
class SceneMatcher {
    private var primaryTags: [String: [String]] = [:]
    private var secondaryTags: [String: [String]] = [:]
    private var conflictTags: [String: [String]] = [:]
    private var sceneBaselines: [String: SceneBaseline] = [:]
    private var sceneLabelMapping: [String: [String]] = [:]
    
    init() {
        loadResources()
    }
    
    // 加载 JSON 资源
    private func loadResources() {
        // 加载 primary_tags.json
        // 加载 scene_baseline.json
        // 加载 scene_label_mapping.json
    }
    
    // 判断是否应排除（截屏/文档）
    func shouldExcludePhoto(visionInfo: PhotoVisionInfo) -> Bool {
        let excludeKeywords = ["screenshot", "document", "text", "receipt",
                               "invoice", "paper", "form", "menu"]
        
        // 检查场景分类
        for scene in visionInfo.sceneClassifications {
            if scene.confidence > 0.5 &&
               excludeKeywords.contains(where: { scene.identifier.lowercased().contains($0) }) {
                return true
            }
        }
        
        // 检查图像分类
        for classification in visionInfo.imageClassifications {
            if classification.confidence > 0.5 &&
               excludeKeywords.contains(where: { classification.identifier.lowercased().contains($0) }) {
                return true
            }
        }
        
        return false
    }
    
    // 匹配场景
    func matchScene(visionInfo: PhotoVisionInfo) -> SceneMatchResult {
        // 收集所有标签
        let labels = collectLabels(from: visionInfo)
        
        // 计算每个场景的评分
        var sceneScores: [(scene: String, score: Float)] = []
        for sceneName in sceneBaselines.keys {
            let score = calculateSceneScore(scene: sceneName, labels: labels)
            sceneScores.append((sceneName, score))
        }
        
        // 排序
        sceneScores.sort { $0.score > $1.score }
        
        // 检查是否需要混合场景
        if sceneScores.count >= 2 {
            let topScore = sceneScores[0].score
            let secondScore = sceneScores[1].score
            
            // 如果前两名评分相近（差值 < 10%），生成混合场景
            if (topScore - secondScore) / topScore < 0.1 {
                return createMixedScene(from: sceneScores.prefix(2).map { $0.scene })
            }
        }
        
        // 单一场景
        let topScene = sceneScores[0].scene
        return SceneMatchResult(
            sceneName: topScene,
            score: sceneScores[0].score,
            confidence: sceneScores[0].score / 10.0,  // 归一化
            baseline: sceneBaselines[topScene]!,
            isMixed: false
        )
    }
    
    // 计算场景评分
    private func calculateSceneScore(scene: String, labels: [String]) -> Float {
        var primaryHitCount: Float = 0
        var secondaryHitCount: Float = 0
        var conflictPenalty: Float = 0
        
        // Primary hits
        if let primaries = primaryTags[scene] {
            primaryHitCount = Float(labels.filter { label in
                primaries.contains(where: { $0.lowercased() == label.lowercased() })
            }.count)
        }
        
        // Secondary hits
        if let secondaries = secondaryTags[scene] {
            secondaryHitCount = Float(labels.filter { label in
                secondaries.contains(where: { $0.lowercased() == label.lowercased() })
            }.count)
        }
        
        // Conflict penalty
        if let conflicts = conflictTags[scene] {
            conflictPenalty = Float(labels.filter { label in
                conflicts.contains(where: { $0.lowercased() == label.lowercased() })
            }.count)
        }
        
        // 评分公式
        return 3 * primaryHitCount + 1 * secondaryHitCount - 2 * conflictPenalty
    }
    
    // 创建混合场景
    private func createMixedScene(from scenes: [String]) -> SceneMatchResult {
        // 加权平均生成混合基准
        let baselines = scenes.compactMap { sceneBaselines[$0] }
        let mixedBaseline = weightedAverageBaseline(baselines)
        
        return SceneMatchResult(
            sceneName: scenes.joined(separator: "+"),
            score: 0,
            confidence: 0.8,
            baseline: mixedBaseline,
            isMixed: true,
            mixedScenes: scenes
        )
    }
    
    // 提取主体类别
    func extractSubjectCategories(visionInfo: PhotoVisionInfo) -> [String] {
        var categories = Set<String>()
        
        // 基于图像分类识别主体
        let subjectKeywords = [
            "person", "face", "portrait": "人物",
            "building", "architecture", "street": "街景",
            "food", "dish", "meal": "食物",
            "plant", "flower", "tree": "植物",
            "animal", "dog", "cat": "动物",
            "sky", "cloud", "sunset": "天空",
            "water", "sea", "ocean": "水体"
        ]
        
        for classification in visionInfo.imageClassifications {
            if classification.confidence > 0.3 {
                for (keywords, category) in subjectKeywords {
                    if keywords.split(separator: ",").contains(where: {
                        classification.identifier.lowercased().contains($0.trimmingCharacters(in: .whitespaces))
                    }) {
                        categories.insert(category)
                    }
                }
            }
        }
        
        return Array(categories)
    }
}
```

### 3. 创建模式检测器

**新文件**: `Project_Color/Services/ColorAnalysis/ModeDetector.swift`

```swift
class ModeDetector {
    
    // 自动检测分析模式
    func detectMode(photoInfos: [PhotoColorInfo]) -> (AnalysisMode, ModeDetectionMetrics) {
        // 计算 S: 场景数量
        let sceneNames = Set(photoInfos.compactMap { $0.sceneMatch?.sceneName })
        let S = sceneNames.count
        
        // 计算 C: 主体类别数
        let allSubjects = photoInfos.flatMap { $0.subjectCategories }
        let uniqueSubjects = Set(allSubjects)
        let C = uniqueSubjects.count
        
        // 计算 V: 偏移稳定性
        let V = calculateOffsetStability(photoInfos: photoInfos)
        
        // 构建指标
        let metrics = ModeDetectionMetrics(
            sceneCount: S,
            offsetStability: V,
            subjectCategoryCount: C,
            sceneNames: Array(sceneNames),
            subjectCategories: Array(uniqueSubjects),
            detectionReason: ""
        )
        
        // 判断模式
        let mode = determineMode(S: S, V: V, C: C, metrics: &metrics)
        
        return (mode, metrics)
    }
    
    // 计算偏移稳定性（标准差）
    private func calculateOffsetStability(photoInfos: [PhotoColorInfo]) -> Float {
        let offsets = photoInfos.compactMap { $0.aestheticOffset }
        guard !offsets.isEmpty else { return 0 }
        
        // 计算各维度的标准差，取平均
        let brightnessStd = standardDeviation(offsets.map { $0.brightnessOffset })
        let contrastStd = standardDeviation(offsets.map { $0.contrastOffset })
        let warmCoolStd = standardDeviation(offsets.map { $0.warmCoolOffset })
        let saturationStd = standardDeviation(offsets.map { $0.saturationOffset })
        
        return (brightnessStd + contrastStd + warmCoolStd + saturationStd) / 4.0
    }
    
    // 判断模式
    private func determineMode(S: Int, V: Float, C: Int, metrics: inout ModeDetectionMetrics) -> AnalysisMode {
        // 跳变审美型：V 极不稳定 且 S≥3
        if V > 0.3 && S >= 3 {
            metrics.detectionReason = "偏移向量极不稳定(V=\(String(format: "%.2f", V)))且场景数≥3，判定为跳变审美型"
            return .jumping
        }
        
        // 混合模式：S≥2 或 C≥3
        if S >= 2 || C >= 3 {
            metrics.detectionReason = "场景数=\(S)或主体类别数=\(C)≥3，判定为混合模式"
            return .mixed
        }
        
        // 组图模式：S=1 且 C≤2 且 V稳定
        if S == 1 && C <= 2 && V < 0.15 {
            metrics.detectionReason = "单场景(S=1)、主体类别≤2、偏移稳定(V=\(String(format: "%.2f", V)))，判定为组图模式"
            return .series
        }
        
        // 默认：混合模式
        metrics.detectionReason = "默认判定为混合模式"
        return .mixed
    }
    
    // 标准差计算
    private func standardDeviation(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Float(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Float(values.count)
        return sqrt(variance)
    }
}
```

### 4. 创建审美偏移计算器

**新文件**: `Project_Color/Services/ColorAnalysis/AestheticOffsetCalculator.swift`

核心逻辑（~500行）：

```swift
class AestheticOffsetCalculator {
    private let colorConverter = ColorSpaceConverter()
    
    func calculateOffset(
        image: CGImage,
        sceneBaseline: SceneBaseline,
        dominantColors: [DominantColor],
        saliencyObjects: [SaliencyObject],
        mode: AnalysisMode
    ) async -> AestheticOffset {
        
        // 1. 提取像素数据
        let pixels = extractPixels(from: image)
        
        // 2. 环境噪声过滤：只保留超出场景基准范围的像素
        let aestheticPixels = filterEnvironmentalNoise(
            pixels: pixels,
            baseline: sceneBaseline
        )
        
        // 3. 主体色域二次过滤（仅混合模式）
        let finalPixels: [Pixel]
        if mode == .mixed {
            finalPixels = filterBySubjectColorRange(
                pixels: aestheticPixels,
                saliencyObjects: saliencyObjects
            )
        } else {
            finalPixels = aestheticPixels
        }
        
        // 4. 计算8维偏移向量
        return AestheticOffset(
            brightnessOffset: calculateBrightnessOffset(finalPixels, baseline: sceneBaseline),
            contrastOffset: calculateContrastOffset(finalPixels, baseline: sceneBaseline),
            warmCoolOffset: calculateWarmCoolOffset(finalPixels, baseline: sceneBaseline),
            saturationOffset: calculateSaturationOffset(finalPixels, baseline: sceneBaseline),
            hueDistribution: calculateHueDistribution(finalPixels),
            shadowRetain: calculateShadowRetain(finalPixels, baseline: sceneBaseline),
            highlightCompress: calculateHighlightCompress(finalPixels, baseline: sceneBaseline),
            colorBalanceOffset: calculateColorBalanceOffset(finalPixels)
        )
    }
    
    // 环境噪声过滤：只保留超出场景基准范围的像素
    private func filterEnvironmentalNoise(
        pixels: [Pixel],
        baseline: SceneBaseline
    ) -> [Pixel] {
        return pixels.filter { pixel in
            let brightness = pixel.lightness
            let saturation = pixel.saturation
            
            // 判断是否在场景合理范围内
            let isInBrightnessRange = (baseline.brightness.min...baseline.brightness.max).contains(brightness)
            let isInSaturationRange = (baseline.saturation.min...baseline.saturation.max).contains(saturation)
            
            // 只保留超出范围的像素（用户调色的结果）
            return !isInBrightnessRange || !isInSaturationRange
        }
    }
    
    // 主体色域二次过滤（混合模式专用）
    private func filterBySubjectColorRange(
        pixels: [Pixel],
        saliencyObjects: [SaliencyObject]
    ) -> [Pixel] {
        // 加载 subject_color_dictionary.json
        let subjectRanges = loadSubjectColorRanges()
        
        return pixels.filter { pixel in
            // 排除主体固有色（如天空的蓝色）
            let isSubjectColor = subjectRanges.contains { range in
                range.hue.contains(pixel.hue) &&
                range.saturation.contains(pixel.saturation) &&
                range.value.contains(pixel.value)
            }
            return !isSubjectColor
        }
    }
    
    // 8个维度的计算方法（省略具体实现）
    private func calculateBrightnessOffset(...) -> Float { ... }
    private func calculateContrastOffset(...) -> Float { ... }
    private func calculateWarmCoolOffset(...) -> Float { ... }
    private func calculateSaturationOffset(...) -> Float { ... }
    private func calculateHueDistribution(...) -> [Float] { ... }
    private func calculateShadowRetain(...) -> Float { ... }
    private func calculateHighlightCompress(...) -> Float { ... }
    private func calculateColorBalanceOffset(...) -> SIMD3<Float> { ... }
}
```

### 5. 创建审美倾向分析器

**新文件**: `Project_Color/Services/ColorAnalysis/AestheticTendencyAnalyzer.swift`

```swift
class AestheticTendencyAnalyzer {
    
    func analyzeAestheticTendency(
        photoInfos: [PhotoColorInfo],
        mode: AnalysisMode
    ) -> AestheticTendency {
        
        switch mode {
        case .series:
            return analyzeSeriesMode(photoInfos: photoInfos)
        case .mixed:
            return analyzeMixedMode(photoInfos: photoInfos)
        case .jumping:
            return analyzeJumpingMode(photoInfos: photoInfos)
        }
    }
    
    // 组图模式：场景内特征重复统计
    private func analyzeSeriesMode(photoInfos: [PhotoColorInfo]) -> AestheticTendency {
        // 统计重复特征（如暗部保留、高光压缩等）
        let offsets = photoInfos.compactMap { $0.aestheticOffset }
        
        // 计算平均偏移
        var coreOffsets: [String: Float] = [:]
        coreOffsets["shadowRetain"] = offsets.map { $0.shadowRetain }.reduce(0, +) / Float(offsets.count)
        coreOffsets["highlightCompress"] = offsets.map { $0.highlightCompress }.reduce(0, +) / Float(offsets.count)
        
        return AestheticTendency(
            crossSceneCore: [:],
            sceneSpecificStyles: [:],
            personalityType: "稳定型",
            personalityDescription: "场景内特征重复出现"
        )
    }
    
    // 混合模式：跨场景一致性过滤
    private func analyzeMixedMode(photoInfos: [PhotoColorInfo]) -> AestheticTendency {
        // 提取跨场景核心审美
        let crossSceneCore = extractCrossSceneCore(photoInfos: photoInfos)
        
        return AestheticTendency(
            crossSceneCore: crossSceneCore,
            sceneSpecificStyles: [:],
            personalityType: crossSceneCore.isEmpty ? "多主题型" : "稳定型",
            personalityDescription: "跨场景稳定偏移"
        )
    }
    
    // 跳变审美型
    private func analyzeJumpingMode(photoInfos: [PhotoColorInfo]) -> AestheticTendency {
        return AestheticTendency(
            crossSceneCore: [:],
            sceneSpecificStyles: [:],
            personalityType: "审美跳变型",
            personalityDescription: "偏移向量跳跃明显，无统一审美"
        )
    }
    
    // 提取跨场景核心审美：至少3个场景的偏移量 > 阈值
    private func extractCrossSceneCore(photoInfos: [PhotoColorInfo]) -> [String: Float] {
        // 按场景分组
        var sceneGroups: [String: [AestheticOffset]] = [:]
        for info in photoInfos {
            guard let sceneName = info.sceneMatch?.sceneName,
                  let offset = info.aestheticOffset else { continue }
            sceneGroups[sceneName, default: []].append(offset)
        }
        
        // 至少3个场景
        guard sceneGroups.count >= 3 else { return [:] }
        
        // 检查各维度的跨场景一致性
        var coreOffsets: [String: Float] = [:]
        
        for dimension in ["brightness", "warmCool", "saturation", "contrast"] {
            let sceneAverages = sceneGroups.mapValues { offsets in
                offsets.map { getDimensionValue($0, dimension: dimension) }.reduce(0, +) / Float(offsets.count)
            }
            
            // 判断是否跨场景一致
            let values = Array(sceneAverages.values)
            let mean = values.reduce(0, +) / Float(values.count)
            let allPositive = values.allSatisfy { $0 > 0.2 }
            let allNegative = values.allSatisfy { $0 < -0.2 }
            
            if allPositive || allNegative {
                coreOffsets[dimension] = mean
            }
        }
        
        return coreOffsets
    }
}
```

### 6. 集成到分析管线

**修改文件**: `Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift`

在 `analyzePhotos` 方法中添加新阶段：

```swift
// 初始化新服务
private let sceneMatcher = SceneMatcher()
private let modeDetector = ModeDetector()
private let offsetCalculator = AestheticOffsetCalculator()
private let tendencyAnalyzer = AestheticTendencyAnalyzer()

// 在 analyzePhotos 方法中：

// 阶段 1: Vision 分析 + 场景匹配 + 排除截屏
var excludedCount = 0
for (index, asset) in assets.enumerated() {
    let image = await requestImage(for: asset)
    let visionInfo = await visionAnalyzer.analyzeImage(image)
    
    // 排除截屏/文档
    if sceneMatcher.shouldExcludePhoto(visionInfo: visionInfo) {
        excludedCount += 1
        continue
    }
    
    // 场景匹配
    let sceneMatch = sceneMatcher.matchScene(visionInfo: visionInfo)
    let subjectCategories = sceneMatcher.extractSubjectCategories(visionInfo: visionInfo)
    
    photoInfo.sceneMatch = sceneMatch
    photoInfo.visionInfo = visionInfo
    photoInfo.subjectCategories = subjectCategories
}

result.excludedPhotoCount = excludedCount

// 阶段 2: 自动检测模式
let (detectedMode, metrics) = modeDetector.detectMode(photoInfos: photoInfos)
result.detectedMode = detectedMode
result.modeDetectionMetrics = metrics

print("🎯 自动检测模式: \(detectedMode.rawValue)")
print("   场景数: \(metrics.sceneCount), 稳定性: \(metrics.offsetStability), 主体类别数: \(metrics.subjectCategoryCount)")

// 阶段 3: 计算审美偏移
for photoInfo in photoInfos {
    let offset = await offsetCalculator.calculateOffset(
        image: image,
        sceneBaseline: photoInfo.sceneMatch!.baseline,
        dominantColors: photoInfo.dominantColors,
        saliencyObjects: photoInfo.visionInfo!.saliencyObjects,
        mode: detectedMode
    )
    photoInfo.aestheticOffset = offset
}

// 阶段 4: 提炼审美倾向
let tendency = tendencyAnalyzer.analyzeAestheticTendency(
    photoInfos: photoInfos,
    mode: detectedMode
)
result.aestheticTendency = tendency
```

### 7. 扩展 AI 评价提示词

**修改文件**: `Project_Color/Services/AI/ColorAnalysisEvaluator.swift`

在 `systemPrompt` 中添加：

```
- detected_mode: "组图模式" | "混合模式" | "跳变审美型"
- mode_detection_metrics: { scene_count, offset_stability, subject_category_count }
- aesthetic_tendency: {
    cross_scene_core: { brightness_offset, warm_cool_offset, ... },
    scene_specific_styles: { ... },
    personality_type: "稳定型" | "审美跳变型" | "多主题型"
  }

根据 detected_mode 调整输出风格：
- 组图模式 + 单一主体类别：使用专业术语（街拍=城市肌理/光影切割，人像=肤色情感/主体疏离感）
- 混合模式：描述跨场景的稳定偏移向量
- 跳变审美型：直接输出人格标签，不强行归纳
```

### 8. UI 展示

**修改文件**: `Project_Color/Views/AnalysisResultView.swift`

在 "AI评价" 标签页添加：

```swift
// 模式检测卡片
if let metrics = result.modeDetectionMetrics,
   let mode = result.detectedMode {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: "brain")
            Text("自动检测模式")
                .font(.headline)
        }
        
        Text(mode.rawValue)
            .font(.title3)
            .fontWeight(.semibold)
        
        Text(metrics.detectionReason)
            .font(.caption)
            .foregroundColor(.secondary)
        
        HStack(spacing: 16) {
            MetricBadge(label: "场景数", value: "\(metrics.sceneCount)")
            MetricBadge(label: "稳定性", value: String(format: "%.2f", metrics.offsetStability))
            MetricBadge(label: "主体类别", value: "\(metrics.subjectCategoryCount)")
        }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
}

// 审美倾向卡片
if let tendency = result.aestheticTendency {
    // ... (展示跨场景核心审美或场景内风格)
}
```

### 9. Core Data 持久化

**修改文件**: `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`

在 `AnalysisSessionEntity` 中添加：

- `aestheticTendencyData: Binary Data?`
- `excludedPhotoCount: Int16`
- `detectedMode: String?`
- `modeDetectionMetricsData: Binary Data?`

在 `PhotoColorEntity` 中添加：

- `sceneMatchData: Binary Data?`
- `aestheticOffsetData: Binary Data?`
- `isExcluded: Bool`
- `subjectCategoriesData: Binary Data?`

### 10. 资源文件补充

**检查并补充**: `Project_Color/Resources/primary_tags.json`

确保包含完整的 primary/secondary/conflict 标签定义：

```json
{
  "primary": { ... },
  "secondary": {
    "indoor_warm_light": ["furniture", "lamp", "shadow", "reflection", ...],
    "daylight_sunny": ["tree", "grass", "shadow", "sunlight", ...],
    ...
  },
  "conflict": {
    "indoor_warm_light": ["outdoor", "daylight", "sunny", ...],
    "daylight_sunny": ["indoor", "night", "artificial light", ...],
    ...
  }
}
```

## 文件清单

### 新建文件

1. `Project_Color/Services/Vision/SceneMatcher.swift` (~350 行)
2. `Project_Color/Services/ColorAnalysis/ModeDetector.swift` (~200 行)
3. `Project_Color/Services/ColorAnalysis/AestheticOffsetCalculator.swift` (~550 行)
4. `Project_Color/Services/ColorAnalysis/AestheticTendencyAnalyzer.swift` (~450 行)

### 修改文件

1. `Project_Color/Models/AnalysisModels.swift` (+200 行)
2. `Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift` (+120 行)
3. `Project_Color/Services/AI/ColorAnalysisEvaluator.swift` (+100 行)
4. `Project_Color/Views/AnalysisResultView.swift` (+180 行)
5. `Project_Color/Persistence/CoreDataManager.swift` (+60 行)
6. `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents` (添加字段)

### 资源文件

1. 补充 `Project_Color/Resources/primary_tags.json` (secondary 和 conflict 标签)

## 预计工作量

- 数据模型扩展：1.5 小时
- 场景匹配服务：2.5 小时
- 模式检测器：1.5 小时
- 审美偏移计算器：3.5 小时
- 审美倾向分析器：2.5 小时
- 管线集成：1.5 小时
- AI 提示词扩展：1 小时
- UI 实现：2.5 小时
- Core Data 持久化：1 小时
- 资源文件补充：0.5 小时
- 测试与调试：2 小时

**总计**：约 20 小时
