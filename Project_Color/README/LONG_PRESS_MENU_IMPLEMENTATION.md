# 长按菜单实现说明

## 功能概述

在相册 Tab 的"收藏"和"素材"两个子 Tab 中，用户可以长按照片集合卡片，弹出操作菜单。

## 视觉设计

### 菜单样式
- **覆盖方式**：菜单直接覆盖在卡片之上（重叠）
- **背景色**：半透明白色 `Color.white.opacity(0.5)`
- **圆角**：与卡片圆角一致（12pt）
- **动画**：淡入淡出效果（0.2秒）

### 菜单内容
菜单分为上下两部分，中间用 `Divider` 分隔：

#### 上半部分 - 收藏/移除收藏
- **图标**：
  - 未收藏时：`heart`（空心）
  - 已收藏时：`heart.fill`（实心）
- **文字**：
  - 未收藏时："收藏"
  - 已收藏时："移除收藏"
- **颜色**：黑色（图标和文字）
- **高度**：卡片高度的一半

#### 下半部分 - 删除
- **图标**：`trash`
- **文字**："删除"
- **颜色**：黑色（图标和文字）
- **高度**：卡片高度的一半

## 交互行为

### 触发方式
- **长按手势**：按住卡片 0.5 秒
- **触发效果**：菜单以淡入动画显示

### 关闭方式
1. 点击菜单上的任意按钮（执行操作后自动关闭）
2. 点击屏幕任意空白处（取消操作）

### 操作确认

#### 收藏/移除收藏
- **素材 Tab**：点击"收藏"后，立即标记为已收藏，移动到"收藏"Tab
- **收藏 Tab**：点击"移除收藏"后，立即取消收藏，移动到"素材"Tab
- **无二次确认**：操作可逆，无需确认

#### 删除
- **二次确认**：点击"删除"后，弹出系统 Alert
- **Alert 内容**：
  - 标题："确认删除"
  - 消息："确定要删除这个分析结果吗？此操作无法撤销。"
  - 按钮：
    - "取消"（取消角色）
    - "删除"（破坏性角色，红色）
- **删除后**：静默删除，无 Toast 提示

## 技术实现

### 状态管理
```swift
// 主视图状态
@State private var anyMenuShowing = false  // 全局：是否有菜单显示
@State private var sessionToDelete: AnalysisSessionInfo?  // 待删除的会话
@State private var showDeleteAlert = false  // 控制删除确认 Alert

// 卡片状态
@State private var showMenu = false  // 控制本卡片菜单显示
@Binding var anyMenuShowing: Bool  // 绑定到主视图的全局状态
```

### 长按手势
```swift
.onLongPressGesture(minimumDuration: 0.5) {
    withAnimation(.easeInOut(duration: 0.2)) {
        showMenu = true
        anyMenuShowing = true  // 通知主视图有菜单显示
    }
}
.onChange(of: anyMenuShowing) { newValue in
    // 当全局菜单状态变为 false 时，关闭本卡片的菜单
    if !newValue && showMenu {
        withAnimation(.easeInOut(duration: 0.2)) {
            showMenu = false
        }
    }
}
```

### 菜单覆盖层
```swift
if showMenu {
    Color.white.opacity(0.5)
        .frame(width: cardSize, height: cardSize)
        .cornerRadius(12)
        .overlay(
            VStack(spacing: 0) {
                // 收藏/移除收藏按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMenu = false
                        anyMenuShowing = false
                    }
                    onFavorite()
                }) { ... }
                Divider()
                // 删除按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showMenu = false
                        anyMenuShowing = false
                    }
                    onDelete()
                }) { ... }
            }
        )
        .transition(.opacity)
}
```

### 全屏透明背景（点击关闭）
```swift
// 在主视图的 ZStack 中
if anyMenuShowing {
    Color.black.opacity(0.001)
        .ignoresSafeArea()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                anyMenuShowing = false
            }
        }
}
```

### 操作回调
```swift
LibrarySessionCard(
    session: session,
    cardSize: cardSize,
    anyMenuShowing: $anyMenuShowing,  // 绑定全局菜单状态
    onFavorite: {
        toggleFavorite(session)
    },
    onDelete: {
        sessionToDelete = session
        showDeleteAlert = true
    }
)
```

## 数据更新

### 切换收藏状态
```swift
private func toggleFavorite(_ session: AnalysisSessionInfo) {
    let newStatus = !session.isFavorite
    CoreDataManager.shared.updateSessionFavoriteStatus(
        sessionId: session.id, 
        isFavorite: newStatus
    )
    viewModel.loadAlbums()  // 重新加载数据
}
```

### 删除会话
```swift
private func deleteSession(_ session: AnalysisSessionInfo) {
    let context = CoreDataManager.shared.container.viewContext
    let fetchRequest: NSFetchRequest<AnalysisSessionEntity> = 
        AnalysisSessionEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
    
    if let entity = try context.fetch(fetchRequest).first {
        context.delete(entity)
        try context.save()
        viewModel.loadAlbums()  // 重新加载数据
    }
}
```

## 布局常量

- **菜单透明度**：`0.5`
- **长按时长**：`0.5` 秒
- **动画时长**：`0.2` 秒
- **图标大小**：`18pt`
- **文字大小**：`16pt`（medium weight）
- **图标文字间距**：`12pt`
- **按钮高度**：卡片高度的 `1/2`

## 用户体验要点

1. **视觉反馈清晰**：半透明白色背景与卡片形成对比，清楚表明菜单已激活
2. **操作直观**：图标+文字组合，降低认知负担
3. **防误操作**：删除操作有二次确认，防止误删重要数据
4. **可逆性**：收藏/移除收藏操作可逆，无需确认
5. **静默删除**：删除后不显示 Toast，保持界面简洁

## 相关文件

- `/Users/linyahuang/Project_Color/Project_Color/Views/AnalysisLibraryView.swift`
  - `LibrarySessionCard`：卡片组件
  - `toggleFavorite(_:)`：切换收藏状态
  - `deleteSession(_:)`：删除会话

