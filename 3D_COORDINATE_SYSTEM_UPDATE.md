# 3D 坐标系统更新：改为第一象限形式

## 📅 更新日期
2025年11月23日

## ✅ 更新状态
**已完成** - 坐标系统已改为从原点出发的三条正轴

---

## 🎯 更新内容

### 修改前：对称十字坐标系
- 坐标轴：从 -max/2 到 +max/2（对称分布）
- 立方体：中心在原点 (0, 0, 0)
- 点的位置：[-80, 80] 范围

### 修改后：第一象限坐标系
- 坐标轴：从 (0, 0, 0) 到 max（只有正轴）
- 立方体：位于第一象限，边界从 (0, 0, 0) 到 (160, 160, 160)
- 点的位置：[0, 160] 范围

---

## 📝 具体修改

### 1. 点的位置映射 (`colorToPosition`)

**修改前**：
```swift
private func colorToPosition(_ normalizedLCh: SIMD3<Float>) -> SCNVector3 {
    let edgeLength = Float(LayoutConstants.cubeEdgeWidth)
    let x = normalizedLCh.x * edgeLength  // [-0.5, 0.5] → [-80, 80]
    let y = normalizedLCh.y * edgeLength
    let z = normalizedLCh.z * edgeLength
    return SCNVector3(x, y, z)
}
```

**修改后**：
```swift
private func colorToPosition(_ normalizedLCh: SIMD3<Float>) -> SCNVector3 {
    let edgeLength = Float(LayoutConstants.cubeEdgeWidth)
    let x = (normalizedLCh.x + 0.5) * edgeLength  // [-0.5, 0.5] → [0, 160]
    let y = (normalizedLCh.y + 0.5) * edgeLength
    let z = (normalizedLCh.z + 0.5) * edgeLength
    return SCNVector3(x, y, z)
}
```

### 2. 立方体位置 (`addBoundingCube`)

**修改前**：
```swift
let cubeNode = SCNNode(geometry: cube)
cubeNode.name = "boundingCube"
scene.rootNode.addChildNode(cubeNode)  // 中心在原点
```

**修改后**：
```swift
let cubeNode = SCNNode(geometry: cube)
cubeNode.name = "boundingCube"
// 将立方体移动到第一象限（中心点在 edgeLength/2）
let halfEdge = Float(LayoutConstants.cubeEdgeWidth) / 2.0
cubeNode.position = SCNVector3(halfEdge, halfEdge, halfEdge)
scene.rootNode.addChildNode(cubeNode)
```

### 3. 坐标轴 (`makeAxisHelper`)

**修改前**：
```swift
let axisLength = Float(length/2)

// X 轴 - 从负到正
node.addChildNode(line(from: SCNVector3(-axisLength, 0, 0), 
                       to: SCNVector3(axisLength, 0, 0), 
                       color: axisColor))

// Y 轴 - 从负到正
node.addChildNode(line(from: SCNVector3(0, -axisLength, 0), 
                       to: SCNVector3(0, axisLength, 0), 
                       color: axisColor))

// Z 轴 - 从负到正
node.addChildNode(line(from: SCNVector3(0, 0, -axisLength), 
                       to: SCNVector3(0, 0, axisLength), 
                       color: axisColor))
```

**修改后**：
```swift
let axisLength = Float(length)

// X 轴 - 从原点到正方向
node.addChildNode(line(from: SCNVector3(0, 0, 0), 
                       to: SCNVector3(axisLength, 0, 0), 
                       color: axisColor))

// Y 轴 - 从原点到正方向
node.addChildNode(line(from: SCNVector3(0, 0, 0), 
                       to: SCNVector3(0, axisLength, 0), 
                       color: axisColor))

// Z 轴 - 从原点到正方向
node.addChildNode(line(from: SCNVector3(0, 0, 0), 
                       to: SCNVector3(0, 0, axisLength), 
                       color: axisColor))
```

### 4. 摄像机位置

**修改前**：
```swift
cameraNode.position = SCNVector3(0, 0, 400)
cameraNode.look(at: SCNVector3(0, 0, 0))
```

**修改后**：
```swift
let halfEdge = Float(LayoutConstants.cubeEdgeWidth) / 2.0
// 摄像机位于第一象限外侧，斜向观察立方体中心
cameraNode.position = SCNVector3(halfEdge + 200, halfEdge + 200, halfEdge + 400)
// 让摄像机看向立方体中心
cameraNode.look(at: SCNVector3(halfEdge, halfEdge, halfEdge))
```

---

## 🎨 坐标系统说明

### 新的坐标系统

```
      Y (C - 色度)
      ↑
      |
      |    立方体
      |   ╱────╱|
      |  ╱    ╱ |
      | ╱────╱  |
      |╱    |   |
      ●─────|───|──→ X (H - 色相)
     ╱      |  ╱
    ╱       | ╱
   ╱        |╱
  ↙ Z (L - 亮度)
```

### 坐标范围

- **原点 (0, 0, 0)**：
  - H = 0° (红色)
  - C = 0 (无色/灰色)
  - L = 0 (黑色)

- **最大点 (160, 160, 160)**：
  - H = 360° (红色，回到起点)
  - C = 110 (最高饱和度)
  - L = 100 (白色)

### 数据映射

| Lab/LCh 值 | 归一化值 | 3D 坐标 |
|-----------|---------|---------|
| H = 0° | -0.5 | X = 0 |
| H = 180° | 0 | X = 80 |
| H = 360° | +0.5 | X = 160 |
| C = 0 | -0.5 | Y = 0 |
| C = 55 | 0 | Y = 80 |
| C = 110 | +0.5 | Y = 160 |
| L = 0 | -0.5 | Z = 0 |
| L = 50 | 0 | Z = 80 |
| L = 100 | +0.5 | Z = 160 |

---

## 🎯 优势

### 1. 更符合数学直觉
- ✅ 类似数学课上的第一象限坐标系
- ✅ 原点有明确的物理意义（黑色、无色、0°）
- ✅ 所有值都是正数，更容易理解

### 2. 更清晰的视觉效果
- ✅ 坐标轴从原点出发，方向明确
- ✅ 不需要对称的负轴，减少视觉干扰
- ✅ 立方体完全位于正空间，边界清晰

### 3. 更好的观察角度
- ✅ 摄像机位于第一象限外侧
- ✅ 可以同时看到三个坐标轴
- ✅ 立方体的位置和朝向更自然

---

## 📚 相关文件

- `Project_Color/Test/threeDTest.swift` - 3D 视图实现（主要修改）
- `Project_Color/Views/AnalysisResultView.swift` - 数据准备（未修改，仍使用 [-0.5, 0.5] 归一化）

---

## 🧪 测试建议

1. **查看 3D 视图**
   - 打开分析结果的"分布" tab
   - 点击"3D 空间"按钮
   - 确认坐标轴从原点出发

2. **验证点的位置**
   - 低色度、低亮度的点应该靠近原点
   - 高色度、高亮度的点应该远离原点
   - 所有点都应该在立方体内部

3. **检查摄像机角度**
   - 应该能同时看到 X、Y、Z 三个轴
   - 立方体应该完全可见
   - 可以通过手势旋转观察不同角度

---

## 🎉 完成状态

- ✅ 点的位置映射更新
- ✅ 立方体位置调整
- ✅ 坐标轴改为正轴
- ✅ 摄像机位置和朝向调整
- ✅ 文档创建

**修改已完成，可以进行测试。**

