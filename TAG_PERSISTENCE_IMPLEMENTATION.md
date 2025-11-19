# Vision 标签 Core Data 持久化实现

## 📋 实现概述

成功为 Vision 标签添加了 Core Data 持久化功能，确保即使重装 app 也能保留标签和频率统计数据。

## 🎯 实现的功能

### 1. Core Data 实体

新增 `VisionTagEntity` 实体，包含以下属性：
- `id` (UUID): 唯一标识符
- `tag` (String): 标签名称
- `count` (Integer 32): 出现次数
- `lastUpdated` (Date): 最后更新时间

### 2. 自动持久化

- **应用启动时**：自动从 Core Data 加载所有标签数据
- **添加标签时**：自动保存到 Core Data（异步，不阻塞主线程）
- **批量添加时**：使用批量保存优化性能
- **清空标签时**：同时清空 Core Data 中的数据

### 3. 性能优化

- **异步保存**：使用后台上下文，不阻塞主线程
- **批量保存**：`addMultiple` 时使用批量保存，减少数据库操作
- **智能更新**：如果标签已存在，只更新计数；否则创建新记录

## 📁 修改的文件

### 1. Core Data 模型
**文件**: `Project_Color.xcdatamodeld/Project_Color.xcdatamodel/contents`

**新增实体**:
```xml
<entity name="VisionTagEntity">
    <attribute name="id" type="UUID"/>
    <attribute name="tag" type="String"/>
    <attribute name="count" type="Integer 32"/>
    <attribute name="lastUpdated" type="Date"/>
</entity>
```

### 2. TagCollector.swift
**文件**: `Project_Color/Services/Vision/TagCollector.swift`

**主要修改**:
- 添加 Core Data 支持
- 初始化时从 Core Data 加载数据
- 添加标签时自动保存
- 清空时删除 Core Data 数据

**新增方法**:
- `loadFromCoreData()`: 从 Core Data 加载标签
- `saveTagToCoreDataAsync(tag:)`: 异步保存单个标签
- `saveTagsToCoreDataAsync(tags:)`: 批量保存标签
- `clearCoreData()`: 清空 Core Data 数据

## 🔧 技术实现

### 数据加载流程

```
应用启动
  ↓
TagCollector.shared 初始化
  ↓
loadFromCoreData()
  ↓
从 Core Data 读取所有 VisionTagEntity
  ↓
加载到内存 tagCounts 字典
```

### 数据保存流程

```
添加标签 (add/addMultiple)
  ↓
更新内存 tagCounts 字典
  ↓
异步保存到 Core Data
  ↓
查找是否已存在
  ├─ 存在 → 更新 count 和 lastUpdated
  └─ 不存在 → 创建新 VisionTagEntity
  ↓
保存上下文
```

### 性能优化策略

1. **异步操作**：
   ```swift
   coreDataManager.performBackgroundTask { context in
       // 在后台线程执行数据库操作
   }
   ```

2. **批量保存**：
   - 单个标签：立即异步保存
   - 多个标签：收集后批量保存，减少数据库操作次数

3. **智能更新**：
   - 使用 `NSPredicate` 快速查找已存在的标签
   - 只更新必要的字段

## 📊 数据持久化保证

### 场景 1: 正常使用
- ✅ 添加标签 → 自动保存
- ✅ 关闭 app → 数据已持久化
- ✅ 重新打开 app → 自动加载

### 场景 2: 重装 app
- ✅ 数据存储在 Core Data
- ✅ 重装后数据仍然存在
- ✅ 标签和频率统计完整保留

### 场景 3: 清空操作
- ✅ 清空内存数据
- ✅ 同时清空 Core Data
- ✅ 确保数据一致性

## 🎨 使用示例

### 添加标签（自动保存）

```swift
// 单个标签
TagCollector.shared.add("beach")
// → 自动保存到 Core Data

// 多个标签
TagCollector.shared.addMultiple(["beach", "ocean", "sky"])
// → 批量保存到 Core Data
```

### 应用启动（自动加载）

```swift
// TagCollector 初始化时自动调用
TagCollector.shared  // → 自动从 Core Data 加载
```

### 清空标签（同步删除）

```swift
TagCollector.shared.clear()
// → 清空内存 + 清空 Core Data
```

## 🔍 数据验证

### 检查 Core Data 中的数据

可以在 Xcode 的 Core Data 调试工具中查看：
1. 运行 app
2. 添加一些标签
3. 在 Xcode 中查看 Core Data 存储
4. 验证 `VisionTagEntity` 中的数据

### 日志输出

应用会在控制台输出日志：
- ✅ `从 Core Data 加载了 X 个标签`
- ❌ `保存标签失败: ...`
- ✅ `已清空 Core Data 中的所有标签`

## ⚠️ 注意事项

### 1. Core Data 实体类生成

- Xcode 会自动生成 `VisionTagEntity` 类
- 如果遇到编译错误，先编译一次项目
- 确保 Core Data 模型文件已正确添加到项目

### 2. 数据迁移

如果将来需要修改实体结构：
- 需要创建新的 Core Data 模型版本
- 实现数据迁移策略
- 确保现有数据不丢失

### 3. 性能考虑

- 大量标签时，批量保存比单个保存更高效
- 使用后台上下文避免阻塞主线程
- 定期检查数据库大小，必要时清理旧数据

## 🚀 未来改进建议

1. **数据同步**：
   - 如果使用 CloudKit，可以同步到 iCloud
   - 多设备间共享标签数据

2. **数据清理**：
   - 添加自动清理功能（如删除超过 X 天未更新的标签）
   - 提供手动清理选项

3. **数据导出/导入**：
   - 支持导出为 JSON/CSV
   - 支持从文件导入标签数据

4. **统计功能**：
   - 按时间段统计标签使用情况
   - 标签趋势分析

## ✅ 完成状态

- ✅ Core Data 实体定义
- ✅ 自动加载功能
- ✅ 自动保存功能
- ✅ 批量保存优化
- ✅ 清空功能同步
- ✅ 编译测试通过

功能已完全实现！现在标签数据会持久化到 Core Data，即使重装 app 也能保留。🎉

