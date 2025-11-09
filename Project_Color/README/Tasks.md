
🏁 第一阶段：项目基础与环境搭建
目标： 建立可运行的空壳 App，打通数据流和基本架构。
-  创建 Xcode 项目（SwiftUI + Core Data + Photos 权限）
-  建立目录结构（Models / ViewModels / Services / Views / MLModels / Config）
-  实现 ProjectColorApp.swift 入口与 App 生命周期管理
-  配置 Core Data Stack（CoreDataManager.swift）
-  定义 Core Data 模型（PhotoEntity / FeatureEntity / StyleEntity / UserPreferenceEntity）
-  编写 Model 层结构体（ColorSwatch, ColorStyle, PhotoFeature）
-  实现基础日志工具 Logger.swift

---
🌈 第二阶段：相册访问与图像预处理
目标： 能从系统相册中读取并显示照片缩略图。
-  PhotoLibraryService — 读取 PHAsset、获取原图/缩略图
-  ImagePreprocessService — 图像缩放（300×300）
-  LAB/HSL 转换工具（LABColorConverter.swift）
-  基础 UI：PhotoGridView（网格展示照片）
-  绑定 ViewModel（IngestionViewModel.swift）
 → 导入相册并在 Core Data 存储基础信息

---
🧠 第三阶段：主色分析与色彩分类
目标： 为每张照片提取主要颜色、分类冷暖。
-  实现 DominantColorService
  - 使用 UIImage + Core Image 或 ColorThief 提取前 5 主色
-  ToneRuleService
  - 根据 LAB 的 a*, b* 值判定冷/暖/中性
-  结果保存进 PhotoEntity（dominantColors / toneCategory）
-  UI：ColorPaletteView（展示主色条与比例）

---
🤖 第四阶段：视觉特征与风格识别
目标： 用 Core ML 提取图像 embedding，并识别视觉风格。
-  引入预训练模型
  - MobileNetV2.mlmodel
  - ResNet50.mlmodel
  - Vision FeaturePrint.mlmodel
-  CoreMLFeatureService — 推理中间层特征
-  VisionFeaturePrintService — 生成 VNFeaturePrintObservation
-  SceneClassifierService — 场景识别（自然/人像/城市等）
-  CLIPEmbeddingService（可选）— HuggingFace 模型转换为 Core ML
-  将特征结果保存至 FeatureEntity
-  初版 MLClusterManager — 聚类相似照片
-  UI：ClusterView（风格分组展示）

---
🧩 第五阶段：偏好分析与聚类
目标： 聚合全图库特征，计算用户偏好中心。
-  EmbeddingIndexService — 建立向量索引（可简单用欧氏距离）
-  PreferenceAnalysisService — 计算平均 embedding、色调分布
-  保存聚类中心到 UserPreferenceEntity
-  UI：PreferenceReportView — 展示偏好统计
-  可视化模块：StatisticsView（饼图、柱状图、时间趋势）

---
💬 第六阶段：AI 语义生成（LLM）
目标： 将结构化分析结果转换为自然语言描述。
-  设计 Prompt 模板（Config/Prompts/style_caption_zh.txt）
-  实现 LLMOrchestrator（封装 API 调用 / 本地模型）
-  生成描述文字与标题（风格命名 / 报告段落）
-  绑定 PreferenceReportView 与描述输出
-  扩展：LLM 自动生成照片标题或系列名

---
⚙️ 第七阶段：性能优化与后台处理
目标： 提升大规模图库分析性能与稳定性。
-  支持并发分析（TaskGroup、Async/Await）
-  支持后台任务（BGProcessingTask）
-  增量扫描相册（仅处理新增图片）
-  处理中断恢复、日志记录
-  模型加载缓存优化（减少 I/O）

---
🎨 第八阶段：体验优化与视觉完善
目标： 提升交互体验和信息呈现。
-  SimilarPhotosView — 查看相似图片组
-  CategoryView — 按冷暖/风格筛选照片
-  SettingsView — 模型版本/启用选项管理
-  主题与动效（色彩过渡、柔和动画）
-  添加本地化（中/英语言支持）

---
☁️ 第九阶段（可选扩展）
目标： 为未来版本打基础。
-  CLIP / ViT 模型支持（多模态特征）
-  iCloud Core Data 同步
-  Android 端（TensorFlow Lite / ML Kit）
-  导出个人视觉报告 PDF
-  LLM 对话模式（“帮我找最温柔的照片”）

---
✅ 最后阶段：测试与发布
-  单元测试（主色提取、聚类准确性）
-  UI Snapshot 测试（颜色展示一致性）
-  性能测试（1000 张图以内分析耗时）
-  TestFlight Beta 内测
-  App Store 审核优化（隐私、模型说明）

---
💡 项目完成后核心成品
- 本地智能风格识别与聚类；
- 个人视觉偏好画像；
- AI 自动风格描述；
- 可视化数据展示；
- 无需上传图片，完全离线运行。
