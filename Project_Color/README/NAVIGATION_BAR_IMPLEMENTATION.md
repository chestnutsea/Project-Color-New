# 分析结果页导航栏实现

## 修改日期
2025-11-23

## 功能概述
为分析结果页添加标准的 iOS 导航栏，包含返回按钮、标题和分享按钮。

## 主要修改

### 1. 添加 NavigationStack

由于使用了自定义转场（`.transition(.move(edge: .trailing))`），`AnalysisResultView` 不在 `HomeView` 的 NavigationStack 内部，因此需要在 `AnalysisResultView` 内部添加自己的 NavigationStack。

```swift
var body: some View {
    NavigationStack {
        GeometryReader { geometry in
            // ... 内容
        }
        .navigationTitle("分析结果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // ... 工具栏按钮
        }
    }
}
```

### 2. 导航栏按钮配置

#### 左侧：返回按钮
```swift
ToolbarItem(placement: .navigationBarLeading) {
    Button(action: {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }) {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
            Text("返回")
        }
    }
}
```

**特点**：
- 使用标准的 `chevron.left` 图标
- 包含"返回"文字
- 触发自定义转场动画返回

#### 中间：标题
```swift
ToolbarItem(placement: .principal) {
    Text("分析结果")
        .font(.headline)
        .foregroundColor(.primary)
}
```

**特点**：
- 使用 `.principal` placement 居中显示
- 使用 `.headline` 字体

#### 右侧：分享按钮
```swift
ToolbarItem(placement: .navigationBarTrailing) {
    Button(action: {
        // TODO: 添加分享功能
    }) {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 17, weight: .semibold))
    }
}
```

**特点**：
- 使用标准的分享图标 `square.and.arrow.up`
- 暂时无动作（预留）

### 3. 导航栏样式

```swift
.toolbarBackground(.visible, for: .navigationBar)
.toolbarBackground(Color(.systemBackground), for: .navigationBar)
```

- 设置导航栏背景可见
- 使用系统标准背景色

## 视觉效果

```
┌─────────────────────────────────┐
│ ← 返回    分析结果       ⬆️     │  ← 导航栏
├─────────────────────────────────┤
│     色彩  │  分布  │  洞察      │  ← Tab Bar
├─────────────────────────────────┤
│                                 │
│         内容区域                 │
│                                 │
└─────────────────────────────────┘
```

## 技术要点

### 1. 自定义转场与 NavigationStack
- 使用自定义转场时，子视图需要有自己的 NavigationStack
- 返回按钮需要手动处理，调用 `onDismiss` 回调触发转场动画

### 2. 工具栏位置
- `.navigationBarLeading`：左侧
- `.principal`：中间（标题位置）
- `.navigationBarTrailing`：右侧

### 3. 按钮样式
- 使用 SF Symbols 图标
- 字体大小：17pt
- 字重：semibold

## 修改文件
- `Project_Color/Views/AnalysisResultView.swift`

## 效果
- ✅ 左侧显示返回按钮（带图标和文字）
- ✅ 中间显示标题"分析结果"
- ✅ 右侧显示分享按钮（图标）
- ✅ 导航栏使用系统标准样式
- ✅ 返回按钮触发自定义转场动画

