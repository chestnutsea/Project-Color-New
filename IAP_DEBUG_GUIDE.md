# 内购调试指南

## 已添加调试日志

我已经在代码中添加了详细的日志，现在请按以下步骤操作：

---

## 步骤 1：Clean Build 并重新运行

```bash
# 在 Xcode 中
Cmd + Shift + K  (Clean Build Folder)
Cmd + R          (Run)
```

---

## 步骤 2：打开控制台

1. 在 Xcode 底部，打开 **Debug Area**（按 `Cmd + Shift + Y`）
2. 确保选择了 **Console** 标签（不是 Variables）
3. 在搜索框中输入 `[IAP]` 可以过滤内购相关日志

---

## 步骤 3：测试购买流程

1. 打开"解锁 AI 视角"界面
2. 观察控制台，应该看到：
   ```
   🛒 [IAP] 开始加载产品...
   🛒 [IAP] 请求产品 IDs: [...]
   🛒 [IAP] 成功获取 X 个产品
   ```

3. 选择一个订阅计划（月度/年度/永久）
4. 点击"立即升级"
5. 观察控制台输出

---

## 可能的错误情况

### 情况 1：产品未加载

**控制台显示**：
```
🛒 [IAP] 成功获取 0 个产品
```
或
```
❌ [IAP] 产品未找到: 6757227914
```

**原因**：
- StoreKit Configuration 文件未正确配置
- Scheme 中未选择 StoreKit Configuration

**解决方案**：
1. 检查 Scheme → Run → Options → StoreKit Configuration 是否选择了 `Configuration.storekit`
2. 确保 `.storekit` 文件已添加到项目中
3. 重新 Clean Build

---

### 情况 2：购买时出错

**控制台显示**：
```
❌ [IAP] 购买过程出错: ...
```

**可能原因**：

#### A. StoreKit Configuration 问题

检查 `.storekit` 文件格式是否正确：
- Product ID 是否匹配
- 产品类型是否正确（订阅 vs 非消耗品）

#### B. 签名/Capability 问题

1. 在 Xcode 中，选择项目 → Target: Project_Color
2. 切换到 **Signing & Capabilities** 标签
3. 确保 **"In-App Purchase"** capability 已添加：
   - 如果没有，点击 **"+ Capability"**
   - 搜索 "In-App Purchase"
   - 添加它

#### C. 模拟器 vs 真机

- **模拟器**：只能使用 StoreKit Configuration File 测试
- **真机**：可以使用 Sandbox 测试账号或 StoreKit Configuration File

---

### 情况 3：验证失败

**控制台显示**：
```
❌ [IAP] 交易验证失败: ...
```

**原因**：
- 在真机上使用了生产环境账号（应该使用 Sandbox 账号）
- 签名配置问题

**解决方案**：
- 在真机上使用 Sandbox 测试账号
- 或者在 Scheme 中启用 StoreKit Configuration（会覆盖真实 App Store）

---

## 步骤 4：查看 StoreKit Transactions

在 Xcode 中：
1. 菜单栏 → **Debug** → **StoreKit** → **Manage Transactions**
2. 可以看到所有测试购买记录
3. 可以删除或退款测试交易

---

## 常见问题

### Q1: 显示"订阅失败"但没有详细错误

**查看控制台**，找到 `❌ [IAP]` 开头的错误日志，复制完整的错误信息。

### Q2: 购买对话框没有弹出

**可能原因**：
- 产品未正确加载
- 查看控制台中的 `🛒 [IAP] 成功获取 X 个产品`，如果 X = 0，说明产品加载失败

### Q3: 真机测试时提示"无法连接到 iTunes Store"

**解决方案**：
1. 在 Scheme 中启用 StoreKit Configuration File
2. 或者在设备上登录 Sandbox 测试账号：
   - **Settings** → **App Store** → **Sandbox Account**

---

## 检查清单

在报告问题前，请确认：

- [ ] Scheme 中已选择 `Configuration.storekit`
- [ ] Clean Build 后重新运行
- [ ] 控制台中看到了 `🛒 [IAP]` 日志
- [ ] 产品数量 > 0
- [ ] 已添加 "In-App Purchase" capability
- [ ] 复制了完整的错误日志

---

## 下一步

运行应用后，请将控制台中的完整日志（从 `🛒 [IAP] 开始加载产品...` 到错误信息）发给我，我会帮你分析具体问题。

特别关注这些日志：
- `🛒 [IAP] 成功获取 X 个产品` - X 应该是 3
- `💳 [IAP] 找到产品: ...` - 应该显示产品信息
- `❌ [IAP] ...` - 任何错误信息

