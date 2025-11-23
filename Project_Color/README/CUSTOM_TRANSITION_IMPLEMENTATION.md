# 自定义转场动画实现总结

## 修改日期
2025-11-23

## 功能概述
将分析结果页的导航方式从 `NavigationStack` 的默认 push 动画改为自定义的 `.transition(.move(edge: .trailing))` 转场动画。

## 主要修改

### 1. HomeView.swift

#### 状态变量修改
```swift
// 移除
@State private var navigationPath = NavigationPath()

// 添加
@State private var showAnalysisResult = false
```

#### 视图结构修改
**之前**：使用 `NavigationStack` 和 `navigationDestination`
```swift
NavigationStack(path: $navigationPath) {
    // 主界面内容
}
.navigationDestination(for: String.self) { destination in
    if destination == "analysisResult", let result = analysisResult {
        AnalysisResultView(result: result)
    }
}
```

**之后**：使用 ZStack 和自定义转场
```swift
ZStack {
    // 主界面
    NavigationStack {
        // 主界面内容
    }
    
    // 分析结果页（使用自定义转场）
    if showAnalysisResult, let result = analysisResult {
        AnalysisResultView(result: result, onDismiss: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showAnalysisResult = false
            }
        })
        .transition(.move(edge: .trailing))
        .zIndex(1)
    }
}
```

#### 导航触发修改
**之前**：
```swift
self.navigationPath.append("analysisResult")
```

**之后**：
```swift
withAnimation(.easeInOut(duration: 0.3)) {
    self.showAnalysisResult = true
}
```

### 2. AnalysisResultView.swift

#### 添加返回回调
```swift
struct AnalysisResultView: View {
    // ... 其他属性
    
    // 自定义返回回调
    var onDismiss: (() -> Void)?
}
```

#### 添加自定义返回按钮
```swift
.toolbar {
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
    
    ToolbarItem(placement: .principal) {
        Text("分析结果")
            .font(.headline)
            .foregroundColor(.primary)
    }
}
```

## 技术要点

### 1. 转场动画
- 使用 `.transition(.move(edge: .trailing))` 实现从右侧滑入的效果
- 使用 `withAnimation(.easeInOut(duration: 0.3))` 控制动画时长和曲线
- 使用 `.zIndex(1)` 确保结果页在主界面之上

### 2. 视图层级
```
ZStack
├── NavigationStack（主界面，zIndex: 0）
│   └── 主界面内容
└── AnalysisResultView（结果页，zIndex: 1）
    └── 带自定义转场的结果内容
```

### 3. 状态管理
- `showAnalysisResult`：控制结果页的显示/隐藏
- `onDismiss` 回调：处理返回操作，触发转场动画

## 优势

1. **无圆角闪烁**：完全避免了 NavigationStack 默认动画的圆角 sheet 效果
2. **流畅转场**：自定义的滑动转场更加流畅自然
3. **完全控制**：可以精确控制动画时长、曲线和方向
4. **向后兼容**：保留了 NavigationStack 的基础结构，不影响其他导航功能

## 效果
- ✅ 分析完成后，结果页从右侧平滑滑入
- ✅ 点击返回按钮，结果页向右侧平滑滑出
- ✅ 无圆角闪烁或 sheet 弹窗效果
- ✅ 动画流畅自然，符合 iOS 原生体验

