# 显影形状功能实现总结

## 概述
在"我的"页面中，将显影模式单独做成一个圆角矩形卡片，并在该卡片内添加了显影形状选项。显影形状提供两个选项：圆形（SF Symbol）和花朵（Assets 中的 SVG）。

## 修改的文件

### 1. BatchProcessSettings.swift
**路径**: `Project_Color/Config/BatchProcessSettings.swift`

**新增内容**:
- 添加了 `DevelopmentShape` 枚举，包含两个选项：
  - `circle`: 圆形
  - `flower`: 花朵
- 添加了 `developmentShape` 静态属性，用于存储和读取用户选择的显影形状
- 默认值为 `.circle`（圆形）

```swift
// MARK: - 显影形状
enum DevelopmentShape: String, Codable, CaseIterable {
    case circle = "circle"
    case flower = "flower"
    
    var displayName: String {
        switch self {
        case .circle: return L10n.DevelopmentShape.circle.localized
        case .flower: return L10n.DevelopmentShape.flower.localized
        }
    }
}

/// 显影形状
static var developmentShape: DevelopmentShape {
    get {
        // 如果从未设置过，默认为圆形
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.developmentShape),
              let shape = try? JSONDecoder().decode(DevelopmentShape.self, from: data) else {
            return .circle
        }
        return shape
    }
    set {
        if let data = try? JSONEncoder().encode(newValue) {
            UserDefaults.standard.set(data, forKey: SettingsKey.developmentShape)
        }
    }
}
```

### 2. LocalizationHelper.swift
**路径**: `Project_Color/Utils/LocalizationHelper.swift`

**新增内容**:
- 添加了 `DevelopmentShape` 枚举，包含本地化键：
  - `title`: "显影形状"
  - `circle`: "图形"
  - `flower`: "花朵"

```swift
// MARK: - Development Shape
enum DevelopmentShape {
    static let title = "development_shape.title"
    static let circle = "development_shape.circle"
    static let flower = "development_shape.flower"
}
```

### 3. 中文本地化字符串
**路径**: `Project_Color/zh-Hans.lproj/Localizable.strings`

**新增内容**:
```
// MARK: - Development Shape
"development_shape.title" = "显影形状";
"development_shape.circle" = "图形";
"development_shape.flower" = "花朵";
```

### 4. 英文本地化字符串
**路径**: `Project_Color/en.lproj/Localizable.strings`

**新增内容**:
```
// MARK: - Development Shape
"development_shape.title" = "Emerge Shape";
"development_shape.circle" = "Circle";
"development_shape.flower" = "Flower";
```

### 5. KitView.swift
**路径**: `Project_Color/Views/Kit/KitView.swift`

**主要修改**:

1. **添加状态变量**:
```swift
@State private var developmentShape: BatchProcessSettings.DevelopmentShape = BatchProcessSettings.developmentShape
```

2. **更新 onAppear**:
```swift
.onAppear {
    developmentMode = BatchProcessSettings.developmentMode
    developmentShape = BatchProcessSettings.developmentShape
}
```

3. **重构卡片结构**:
   - 将原来的 `featuresCard` 拆分，移除了显影模式
   - 新增 `developmentCard`，包含显影模式和显影形状
   - 卡片顺序调整为：
     1. AI 解锁卡片
     2. 功能入口卡片（云相册 + 照片暗房）
     3. **显影设置卡片（显影模式 + 显影形状）** ← 新增
     4. 色彩实验室卡片
     5. 更多选项卡片

4. **新增 developmentCard**:
```swift
// MARK: - 显影设置卡片（显影模式 + 显影形状）
private var developmentCard: some View {
    VStack(spacing: 0) {
        // 显影模式
        HStack(spacing: 12) {
            Image(systemName: "camera.filters")
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 28)
            
            Text(L10n.Mine.developmentMode.localized)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Menu {
                ForEach(BatchProcessSettings.DevelopmentMode.allCases, id: \.self) { mode in
                    Button {
                        developmentMode = mode
                        BatchProcessSettings.developmentMode = mode
                    } label: {
                        if mode == developmentMode {
                            Label(mode.displayName, systemImage: "checkmark")
                        } else {
                            Text(mode.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(developmentMode.displayName)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 110, alignment: .trailing)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, Layout.rowHorizontalPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
        .contentShape(Rectangle())
        
        // 显影形状
        HStack(spacing: 12) {
            Image("shape")
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.primary)
                .frame(width: 20, height: 20)
                .frame(width: 28)
            
            Text(L10n.DevelopmentShape.title.localized)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 显影形状选择器（使用图标）
            HStack(spacing: 16) {
                // 圆形选项
                Button {
                    developmentShape = .circle
                    BatchProcessSettings.developmentShape = .circle
                } label: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(developmentShape == .circle ? .primary : .secondary.opacity(0.5))
                }
                
                // 花朵选项
                Button {
                    developmentShape = .flower
                    BatchProcessSettings.developmentShape = .flower
                } label: {
                    Image("flower")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(developmentShape == .flower ? .primary : .secondary.opacity(0.5))
                        .frame(width: 20, height: 20)
                }
            }
        }
        .padding(.horizontal, Layout.rowHorizontalPadding)
        .padding(.vertical, Layout.rowVerticalPadding)
        .contentShape(Rectangle())
    }
    .background(Color(.systemBackground))
    .cornerRadius(Layout.cornerRadius)
}
```

## UI 设计特点

### 显影形状选择器
- **图标**: 使用 Assets 中的 `shape.svg` 作为标题图标
- **选项展示**: 使用下拉菜单（Menu），与显影模式保持一致的交互方式
  - 圆形: SF Symbol `circle.fill`
  - 花朵: Assets 中的 `flower.svg`
- **下拉菜单标签**: 显示当前选中的图标 + 文字 + 下拉箭头
- **菜单选项**: 每个选项显示图标 + 文字，选中项显示 checkmark
- **颜色**: 使用 `.secondary` 灰色，与显影模式保持一致

### 卡片设计
- **背景**: `.systemBackground`（系统背景色）
- **圆角**: 20pt（与其他卡片保持一致）
- **内边距**: 
  - 水平: 16pt
  - 垂直: 14pt
- **分隔**: 显影模式和显影形状之间无分隔线，自然堆叠

## 数据持久化
- 使用 `UserDefaults` 存储用户选择
- 键名: `"developmentShape"`
- 编码方式: JSON
- 默认值: `.circle`（圆形）

## 使用方法

### 读取当前设置
```swift
let currentShape = BatchProcessSettings.developmentShape
```

### 更新设置
```swift
BatchProcessSettings.developmentShape = .flower
```

### 在其他视图中使用
```swift
@State private var shape = BatchProcessSettings.developmentShape

// 在视图中根据 shape 的值做不同处理
switch shape {
case .circle:
    // 使用圆形显影
case .flower:
    // 使用花朵显影
}
```

## 测试建议
1. 打开 App，进入"我的"页面
2. 查看显影设置卡片是否正确显示
3. 点击圆形和花朵图标，确认选中状态切换正常
4. 关闭 App 重新打开，确认设置被正确保存
5. 切换系统语言（中文/英文），确认文本正确本地化
6. 切换系统主题（亮色/暗色），确认图标颜色正确显示

## 注意事项
1. 确保 Assets 中存在 `shape.svg` 和 `flower.svg` 文件
2. 图标使用 `.renderingMode(.template)` 以支持颜色自定义
3. 选中状态使用 `.primary` 颜色，确保在亮色和暗色模式下都清晰可见
4. 未选中状态使用半透明灰色，提供视觉层次

## 后续扩展
如果需要添加更多显影形状选项：
1. 在 `DevelopmentShape` 枚举中添加新的 case
2. 在本地化文件中添加对应的翻译
3. 在 `developmentCard` 的 HStack 中添加新的按钮
4. 确保 Assets 中有对应的图标资源

## 显影页面集成

### 修改文件
**路径**: `Project_Color/Views/EmergeView.swift`

### 实现内容

1. **状态管理**：
   - 添加 `lastKnownDevelopmentShape` 状态变量，追踪显影形状变化
   - 在 `onAppear` 中检测显影形状变化，当形状改变时刷新视图（无需重新聚类）

2. **色调/融合模式的形状切换**：
   ```swift
   let currentShape = BatchProcessSettings.developmentShape
   
   if currentShape == .circle {
       Circle()
           .fill(circle.color)
           .frame(width: circle.radius * 2, height: circle.radius * 2)
   } else {
       Image("flower")
           .resizable()
           .renderingMode(.template)
           .foregroundColor(circle.color)
           .frame(width: circle.radius * 2, height: circle.radius * 2)
   }
   ```

3. **发光效果适配**：
   - 修改 `glowingCircleGlow` 函数，根据形状类型显示不同的发光效果
   - 圆形：使用圆形模糊
   - 花朵：外层使用圆形渐变，中层使用花朵形状模糊

4. **影调模式不受影响**：
   - 影调模式（圆角正方形）保持不变
   - 只有色调模式和融合模式会根据设置改变形状

### 工作原理

1. **读取设置**：
   ```swift
   let currentShape = BatchProcessSettings.developmentShape
   ```

2. **根据设置渲染**：
   - 如果 `currentShape == .circle`：显示圆形
   - 如果 `currentShape == .flower`：显示花朵

3. **大小映射**：
   - 使用相同的 `circle.radius` 值
   - 圆形：直径 = `radius * 2`
   - 花朵：宽高 = `radius * 2`（整体缩放）

4. **颜色填充**：
   - 使用 `.renderingMode(.template)` 将 SVG 转为模板
   - 使用 `.foregroundColor(circle.color)` 填充每个圆形的颜色

5. **性能优化**：
   - 形状改变时只刷新视图，不重新聚类
   - 保持原有的数据和位置

## 花朵旋转动画

### 实现细节

1. **数据结构扩展**：
   - 在 `ColorCircle` 结构体中添加 `rotation: Angle` 属性
   - 记录每个花朵的当前旋转角度

2. **旋转速度**：
   ```swift
   static let rotationSpeed: Double = 0.3  // 度/帧，60fps下约18度/秒
   ```
   - 所有花朵以相同速度同向旋转（顺时针）
   - 约20秒旋转一圈（360度 ÷ 18度/秒 = 20秒）

3. **运动更新**：
   ```swift
   // 在 updatePerlinNoiseMotion 中更新旋转
   c.rotation = Angle(degrees: c.rotation.degrees + PerlinMotion.rotationSpeed)
   ```

4. **视图应用**：
   ```swift
   Image("flower")
       .rotationEffect(circle.rotation)  // 主花朵
   
   // 发光层也同步旋转
   Image("flower")
       .rotationEffect(circle.rotation)
       .blur(radius: r * 0.25)
   ```

5. **性能优化**：
   - 旋转只在花朵模式下生效
   - 圆形模式不受影响
   - 旋转与位置移动同步更新，无额外性能开销

### 视觉效果

- **圆形模式**：静态圆形，随 Perlin Noise 漂移
- **花朵模式**：花朵缓慢旋转 + 随 Perlin Noise 漂移
- **影调模式**：圆角正方形，不旋转

## 完成状态
✅ 所有文件修改完成
✅ 无编译错误
✅ 本地化支持完整（中文/英文）
✅ UI 设计符合要求
✅ 数据持久化实现
✅ 显影页面集成完成
✅ 支持圆形和花朵形状切换
✅ 发光效果适配
✅ 大小映射关系保持不变
✅ 花朵旋转动画实现（缓慢同向旋转）

