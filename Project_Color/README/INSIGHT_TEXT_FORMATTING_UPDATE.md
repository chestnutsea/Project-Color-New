# 洞察页文字格式化更新

## 修改日期
2025-11-23

## 功能概述
改进洞察页的文字显示，支持 Markdown 加粗格式，并优化视觉呈现。

## 主要修改

### 1. 支持 `**文字**` 加粗格式

#### 新增 FormattedTextView 组件
创建了专门的文本格式化组件，支持解析和显示 Markdown 加粗格式：

```swift
struct FormattedTextView: View {
    let text: String
    
    var body: some View {
        let segments = parseMarkdownBold(text)
        
        segments.reduce(Text("")) { result, segment in
            if segment.isBold {
                return result + Text(segment.text).fontWeight(.bold)
            } else {
                return result + Text(segment.text)
            }
        }
    }
    
    private func parseMarkdownBold(_ text: String) -> [TextSegment] {
        // 使用正则表达式解析 **文字** 格式
        let pattern = "\\*\\*([^*]+)\\*\\*"
        // ... 解析逻辑
    }
}
```

#### 功能特点
- **自动识别**：自动识别文本中的 `**文字**` 格式
- **去除符号**：显示时去除 `**` 符号
- **加粗显示**：被标记的文字以粗体显示
- **混合文本**：支持普通文本和加粗文本混合显示

### 2. 去除带颜色的背景

**之前**：
```swift
Text(mainText)
    .padding()
    .background(dominantColor.opacity(0.08))  // 带颜色的背景
    .cornerRadius(KeywordTagLayout.cornerRadius)
```

**之后**：
```swift
FormattedTextView(text: mainText)
    // 无背景色
```

### 3. 调整照片高度

修改照片展示区域的高度比例：

```swift
// PhotoCarouselLayout
static let photoHeightRatio: CGFloat = 0.7  // 从 0.8 改为 0.7
```

### 4. 简化文本处理逻辑

**之前**：
```swift
private func parseTextAndKeywords(_ text: String) -> (mainText: String, keywords: String) {
    let cleanedText = removeMarkdownBold(text)  // 先去除所有加粗符号
    // ... 处理
}

private func removeMarkdownBold(_ text: String) -> String {
    // 使用正则表达式去除 **text** 和 *text*
}
```

**之后**：
```swift
private func parseTextAndKeywords(_ text: String) -> (mainText: String, keywords: String) {
    // 直接处理原始文本，保留 ** 符号
    // FormattedTextView 会负责解析和显示
}
```

## 修改文件

1. **Project_Color/Views/AnalysisResultView.swift**
   - 添加 `FormattedTextView` 组件
   - 修改 `formattedEvaluationView` 使用新组件
   - 简化 `parseTextAndKeywords` 逻辑
   - 移除 `removeMarkdownBold` 函数

2. **Project_Color/Views/Components/PhotoCardCarousel.swift**
   - 修改 `photoHeightRatio` 从 0.8 到 0.7

3. **Project_Color/Views/HomeView.swift**
   - 修复结构性错误（多余的闭合括号）

## 视觉效果

### 之前
- 文字显示在带颜色的背景框内
- 所有文字都是普通字重
- `**文字**` 符号被去除但不加粗

### 之后
- 文字直接显示，无背景色
- `**文字**` 中的文字以粗体显示
- `**` 符号被自动去除
- 照片占用空间更小（70% vs 80%）

## 示例

**输入文本**：
```
这组照片展现了**温暖明亮**的色调，以**柔和的米色**和**淡雅的粉色**为主。
整体氛围**轻松愉悦**，适合表达**日常生活**的美好瞬间。
```

**显示效果**：
- "温暖明亮"、"柔和的米色"、"淡雅的粉色"、"轻松愉悦"、"日常生活" 以粗体显示
- `**` 符号不显示
- 无背景色，文字直接呈现

## 技术要点

1. **正则表达式解析**：使用 `\\*\\*([^*]+)\\*\\*` 匹配 `**文字**` 格式
2. **Text 组合**：使用 SwiftUI 的 `Text` + 运算符组合多个文本段
3. **字重控制**：使用 `.fontWeight(.bold)` 设置加粗
4. **保持选择性**：保留 `.textSelection(.enabled)` 支持文本选择和复制

