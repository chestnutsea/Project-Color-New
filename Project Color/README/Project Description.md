路径：cd /Users/linyahuang/Project\ Color

🎨 Project Color（知色）
一款基于本地视觉计算与 AI 语义分析的 智能色彩风格分析 App
 iOS 原生 SwiftUI 应用，结合 Core ML + Vision + LLM，实现照片的主色提取、风格识别与个人视觉偏好分析。

---
🧱 一、技术栈总览
层级
技术组件
作用
前端 UI 层
SwiftUI
构建响应式界面、数据驱动视图（PhotoGridView、ColorPaletteView、ClusterView 等）
架构模式
MVVM + Service Oriented
Model = Core Data / Codable Struct；ViewModel = 逻辑协调层；Service = 算法与系统接口
图像处理
Core Image、UIImage、CGImage
图像缩放、像素读取、色彩空间转换
色彩分析
LAB/HSL 转换 + ToneRuleService
计算明度/饱和度/色相倾向（冷暖中性）
主色提取
DominantColorService （基于 Core ML 或直方图/超像素）
提取 N 个主色簇及比例，替代 K-Means 聚类
视觉特征提取
Core ML 模型：MobileNetV2、ResNet50、Vision FeaturePrint
输出图像 embedding，用于风格识别与相似性分析
场景识别
VNSceneClassifier (Vision)
获取“城市/人像/自然”等标签，辅助风格判断
多模态特征
Hugging Face → Core ML 转换 CLIP ViT-B/32
获取语义感知的视觉 embedding（风格级特征）
聚类与索引
Core ML + 自定义 HNSW / KDTree 索引
相似风格聚类、快速相似图片查找
偏好画像
PreferenceAnalysisService
对所有 embedding 聚类求中心，分析用户视觉偏好
语义生成
LLMOrchestrator + Prompt 模板
将结构化结果 → 自然语言风格描述与报告
本地存储
Core Data
持久化 Photo / Color / Feature / Style / Preference 实体
并发机制
Swift Concurrency (TaskGroup、Async/Await) + BGProcessingTask
并行处理上千张图片、支持后台分析
系统接口
PhotoKit (PHAsset)、FileManager
相册访问、缩略图加载、数据缓存
日志与工具
自定义 Logger、MathUtils、FeatureFusion
调试、向量运算与多模型融合
可选后端扩展
iCloud Core Data / CloudKit
数据同步（非必需）

---
📊 二、功能总览
🌈 1. 主色提取与色彩分析
- 自动缩放至 300×300 像素进行处理；
- 从每张照片提取 5 个主要颜色及其占比；
- 按 LAB 空间判断冷/暖/中性；
- 输出色卡条、颜色比例图。
🧭 2. 色彩风格识别
- 使用 Core ML 模型（MobileNetV2、ResNet50 或 CLIP）识别整体视觉风格；
- 输出标签如“清冷日系”“复古胶片”“高饱和街头”“奶油风”等；
- Vision SceneClassifier 辅助判断场景背景。
🔍 3. 相似风格聚类
- 利用 Vision FeaturePrint 与 CLIP embedding 聚类；
- 自动分组相似风格图片；
- 支持“查看相似照片”功能。
📈 4. 统计与可视化
- 全图库色彩统计：最常见色相、冷暖比例；
- 风格分布统计：每类风格占比；
- 时间趋势图：按拍摄时间分析偏好演变。
🧠 5. 用户视觉偏好分析
- 聚类用户的全部 Feature embedding；
- 计算中心向量与平均色彩参数；
- 自动生成“视觉偏好画像”；
- 如“你偏爱 蓝灰调街景、暖黄人像”。
💬 6. LLM 智能语义生成
- 将风格向量 + 色彩比例 + 场景标签 组合成 Prompt；
- LLM 生成文字描述或标题，例如：
- “这是一组带有奶油色调的柔光人像，整体氛围温柔而安静。”
- 支持报告式总结与可视化。
🪄 7. 实时相似风格推荐
- 在浏览照片时推荐同类风格图；
- 支持按色调搜索（如“找出与此图风格相似的蓝灰调作品”）。
⚙️ 8. 模型与设置管理
- 模型版本、路径与来源（ModelCards）；
- 是否启用 CLIP / SceneClassifier；
- 调试信息与性能统计。

---
🗃️ 三、Core Data 模型关系
实体
关键字段
说明
PhotoEntity
assetLocalId, toneCategory, sceneLabel
核心照片信息
ColorSwatchEntity
hex, ratio, l,a,b
主色数据（1:N）
FeatureEntity
modelSource, vector
模型 embedding
StyleEntity
label, confidence
风格识别结果
UserPreferenceEntity
dominantTone, styleDistribution
用户整体偏好中心

---
⚙️ 四、核心算法流程
1️⃣ 读取相册 PHAsset
     ↓
2️⃣ ImagePreprocessService
     ↓
3️⃣ DominantColorService → ToneRuleService
     ↓
4️⃣ CoreMLFeatureService / FeaturePrintService / CLIPEmbeddingService
     ↓
5️⃣ FeatureFusion + MLClusterManager
     ↓
6️⃣ PreferenceAnalysisService（计算聚类中心）
     ↓
7️⃣ LLMOrchestrator（生成语义报告）
支持 TaskGroup 并行执行，实现千张图片级离线批量分析。

---
🧩 五、平台特性与性能优化
模块
优化手段
图像加载
缩放到 300×300 减少内存占用
向量存储
[Float] → Binary Data 序列化
并发
Swift TaskGroup + BGProcessingTask
数据存储
Core Data 持久化、可选 iCloud 同步
模型调用
预编译 Core ML 模型（无训练）
安全性
全程本地推理，不上传照片
延迟控制
图像分析和 LLM 语义生成解耦后台运行

---
💡 六、可扩展方向
1. 跨平台 Android 版本：使用 TensorFlow Lite / ML Kit 复刻 Core ML 部分。
2. 色彩检索功能：按颜色值筛选图库。
3. 创作者模式：导出风格报告或 UI 主题色。
4. AI 滤镜推荐：根据识别出的风格匹配合适的调色预设。
5. 与 LLM 对话式交互：
“帮我找最近三个月最温柔的色调照片。”

---
✅ 七、总结一句话
Project Color = 知色
一款结合 视觉特征提取（Core ML / CLIP / FeaturePrint）
与 语言模型语义生成（LLM Orchestrator） 的
本地智能相册分析 App，
让用户“认识自己的视觉偏好”，用数据理解“美”的模式。
