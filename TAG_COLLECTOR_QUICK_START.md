# Vision 标签收集功能 - 快速开始

## 🚀 快速开始（3 步）

### 1️⃣ 分析照片
在主界面选择相册，拖动照片到扫描器进行分析。

### 2️⃣ 打开标签库
点击主界面右上角的 **🏷️ 标签图标**。

### 3️⃣ 查看标签
浏览所有收集到的 Vision 标签！

---

## 📍 按钮位置

主界面右上角，从右到左依次为：
```
[🕐 历史记录] [⚙️ 设置] [🏷️ 标签库] ← 新增
```

---

## 🎯 主要功能

| 功能 | 说明 |
|------|------|
| **自动收集** | 分析照片时自动收集标签 |
| **去重显示** | 自动去除重复标签 |
| **搜索过滤** | 实时搜索标签 |
| **统计信息** | 显示标签总数 |
| **清空功能** | 一键清空所有标签 |

---

## 💡 使用场景

### 📊 了解照片内容
快速了解照片库中包含哪些类型的内容（风景、人物、建筑等）。

### 🎨 发现拍摄偏好
通过标签分布发现自己的拍摄偏好和风格。

### 🔍 辅助照片管理
为照片分类和整理提供参考依据。

---

## 🔧 技术特点

- ✅ **线程安全**：支持并发分析
- ✅ **自动去重**：使用 Set 数据结构
- ✅ **实时搜索**：大小写不敏感
- ✅ **优雅空状态**：友好的用户提示

---

## 📝 标签来源

标签来自 Apple Vision 框架：
- **场景识别**：beach, sunset, indoor, outdoor...
- **图像分类**：cat, dog, flower, building...

---

## 🎓 开发者参考

### 使用 TagCollector

```swift
// 添加标签
TagCollector.shared.add("sunset")
TagCollector.shared.addMultiple(["beach", "ocean"])

// 获取标签
let tags = TagCollector.shared.export()
let count = TagCollector.shared.count()

// 清空标签
TagCollector.shared.clear()
```

### 文件位置

- **服务类**：`Project_Color/Services/Vision/TagCollector.swift`
- **界面**：`Project_Color/Views/CollectedTagsView.swift`
- **集成点**：`VisionAnalyzer.swift` 和 `HomeView.swift`

---

## 📚 更多信息

- 详细实现说明：`TAG_COLLECTOR_IMPLEMENTATION.md`
- 功能演示：`TAG_COLLECTOR_DEMO.md`

---

## ✨ 就这么简单！

现在你可以开始使用 Vision 标签收集功能了。分析照片，查看标签，发现你的摄影风格！

