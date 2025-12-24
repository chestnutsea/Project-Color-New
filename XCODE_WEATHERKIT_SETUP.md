# Xcode WeatherKit 配置指南

## ⚠️ 重要：必须手动完成此步骤

代码已经全部实现完成，但需要在 Xcode 中手动启用 WeatherKit capability。

## 配置步骤

1. **打开 Xcode 项目**
   ```
   cd /Users/linyahuang/Project_Color
   open Project_Color.xcodeproj
   ```

2. **选择项目配置**
   - 在左侧项目导航器中，点击最顶部的 **Project_Color** 项目图标
   - 在中间区域选择 **TARGETS** 下的 **Project_Color**

3. **添加 WeatherKit Capability**
   - 切换到 **Signing & Capabilities** 标签（顶部标签栏）
   - 点击 **+ Capability** 按钮（左上角）
   - 在搜索框中输入 **WeatherKit**
   - 点击 **WeatherKit** 添加

4. **验证配置**
   - 确认在 Capabilities 列表中看到 **WeatherKit**
   - 确保没有红色错误提示
   - 如果有错误，检查你的 Apple Developer 账号是否已登录

5. **构建并运行**
   - 按 `Cmd + B` 构建项目
   - 按 `Cmd + R` 运行到模拟器或真机

## 测试步骤

1. **进入 Kit 页面**
   - 在底部 Tab Bar 点击 "Kit" 图标

2. **选择 Garden 显影形状**
   - 找到 "显影形状" 设置
   - 选择 "花园" (Garden)

3. **进入显影页面**
   - 切换到 "Emerge" 页面
   - 应该会弹出位置权限请求

4. **授权并查看**
   - 点击 "允许" 授权位置权限
   - 稍等几秒，左上角应该显示天气信息
   - 格式：`位置名称 · 天气 · 温度 (最低-最高)`

## 可能的问题

### 问题 1：找不到 WeatherKit
**原因**：Apple Developer 账号未启用 WeatherKit
**解决**：
- 访问 https://developer.apple.com
- 登录你的开发者账号
- 确认 WeatherKit 服务已启用

### 问题 2：模拟器无法获取位置
**原因**：模拟器需要手动设置位置
**解决**：
- 在模拟器菜单中选择 **Features > Location > Custom Location**
- 输入经纬度或选择预设位置（如 Apple Park）

### 问题 3：真机无法获取天气
**原因**：网络连接或 GPS 信号问题
**解决**：
- 确保设备已连接网络
- 确保设备 GPS 功能已开启
- 在设置中检查 Feelm 的位置权限

### 问题 4：天气信息不显示
**原因**：可能是权限被拒绝或网络问题
**解决**：
- 检查 Xcode 控制台的日志输出（搜索 "📍"）
- 如果看到权限被拒绝，在设置中重新授权
- 如果看到网络错误，检查网络连接

## 注意事项

- WeatherKit 需要真实的 Apple Developer 账号（免费账号可能不支持）
- WeatherKit 有每月调用次数限制
- 首次请求可能需要几秒钟时间
- 如果用户拒绝位置权限，不会显示任何内容（这是预期行为）

## 完成后

配置完成后，你可以：
- 在不同显影形状之间切换，验证只有 garden 模式显示天气
- 测试权限拒绝的情况
- 测试中英文切换
- 查看天气信息的显示效果

配置完成后，删除此文件即可。

