# StoreKit Configuration File 配置指南

## 什么是 StoreKit Configuration File？

StoreKit Configuration File 允许你在本地测试内购功能，无需等待 App Store Connect 审核通过。它会模拟真实的 StoreKit 环境，包括不同地区的价格。

---

## 步骤 1：创建 StoreKit Configuration File

### 在 Xcode 中创建：

1. **打开 Xcode 项目**
2. **右键点击** `Project_Color` 文件夹（在项目导航器中）
3. 选择 **New File...**
4. 在模板选择器中：
   - 滚动到底部找到 **"StoreKit Configuration File"**
   - 或者在搜索框输入 "StoreKit"
5. 点击 **Next**
6. 文件名保持默认：`Configuration.storekit`
7. 确保 **Target** 选中了 `Project_Color`
8. 点击 **Create**

---

## 步骤 2：添加产品到 Configuration File

创建完成后，Xcode 会自动打开 `.storekit` 文件的编辑器。

### 添加月度订阅：

1. 点击左下角的 **"+"** 按钮
2. 选择 **"Add Subscription"**
3. 填写信息：
   - **Reference Name**: `Monthly Subscription`
   - **Product ID**: `6757227914`
   - **Price**: 选择价格等级
     - 中国区：选择 `Tier 18` (¥18)
     - 美国区：会自动对应 $2.99
   - **Subscription Duration**: `1 Month`
   - **Localization** (可选):
     - 点击 **"Add Localization"**
     - 语言：`Chinese (Simplified)`
     - Display Name: `月度订阅`
     - Description: `每月 AI 分析服务`

### 添加年度订阅：

1. 再次点击 **"+"** → **"Add Subscription"**
2. 填写信息：
   - **Reference Name**: `Yearly Subscription`
   - **Product ID**: `6757228325`
   - **Price**: 选择价格等级
     - 中国区：选择 `Tier 68` (¥68)
     - 美国区：会自动对应 $14.99
   - **Subscription Duration**: `1 Year`
   - **Localization**:
     - 语言：`Chinese (Simplified)`
     - Display Name: `年度订阅`
     - Description: `每年 AI 分析服务`

### 添加永久购买：

1. 点击 **"+"** → **"Add Non-Consumable"**
2. 填写信息：
   - **Reference Name**: `Lifetime Purchase`
   - **Product ID**: `6757228243`
   - **Price**: 选择价格等级
     - 中国区：选择 `Tier 198` (¥198)
     - 美国区：会自动对应 $39.99
   - **Localization**:
     - 语言：`Chinese (Simplified)`
     - Display Name: `永久解锁`
     - Description: `一次购买，永久使用`

---

## 步骤 3：配置 Xcode Scheme 使用 StoreKit File

### 设置方法：

1. 在 Xcode 顶部工具栏，点击 **Scheme 选择器**（显示 "Project_Color" 的地方）
2. 选择 **"Edit Scheme..."**
3. 在左侧选择 **"Run"**
4. 切换到 **"Options"** 标签页
5. 找到 **"StoreKit Configuration"** 选项
6. 从下拉菜单中选择 **`Configuration.storekit`**
7. 点击 **"Close"**

---

## 步骤 4：测试

### 运行应用：

1. **Clean Build Folder**: `Cmd + Shift + K`
2. **重新运行**: `Cmd + R`
3. 打开"解锁 AI 视角"界面
4. 现在应该能看到从 StoreKit Configuration 读取的真实价格了！

### 验证价格显示：

- 如果你的设备/模拟器设置为**中国区**：应该显示 ¥18、¥68、¥198
- 如果设置为**美国区**：应该显示 $2.99、$14.99、$39.99
- 价格会根据你在 StoreKit Configuration 中设置的价格等级自动调整

---

## 步骤 5：测试购买流程

### StoreKit Configuration 的测试功能：

1. **模拟购买**：点击购买按钮会弹出模拟的购买确认对话框
2. **测试成功/失败**：可以选择批准或取消购买
3. **查看交易**：
   - 在 Xcode 底部打开 **Debug Area** (`Cmd + Shift + Y`)
   - 切换到 **"Console"** 标签
   - 选择 **"StoreKit Transactions"** 查看所有交易记录

### 管理测试交易：

在 Xcode 中，选择菜单：
- **Debug** → **StoreKit** → **Manage Transactions**
- 可以查看、删除、退款测试购买

---

## 价格等级参考

如果不确定选择哪个价格等级，参考以下常见等级：

| 价格等级 | 中国 (CNY) | 美国 (USD) | 欧盟 (EUR) |
|---------|-----------|-----------|-----------|
| Tier 18 | ¥18       | $2.99     | €2.99     |
| Tier 68 | ¥68       | $9.99     | €9.99     |
| Tier 198| ¥198      | $29.99    | €29.99    |

**注意**：实际价格可能略有不同，Apple 会根据汇率和当地税收调整。

---

## 常见问题

### Q1: 创建后看不到 StoreKit Configuration File 选项？

**解决方案**：
- 确保 Xcode 版本 ≥ 12.0
- 重启 Xcode
- 检查文件是否在项目中（不是只在文件系统中）

### Q2: 价格仍然显示 fallback 值？

**检查清单**：
1. ✅ Scheme 中已选择 StoreKit Configuration
2. ✅ Product ID 完全匹配（包括大小写）
3. ✅ Clean Build Folder 后重新运行
4. ✅ 检查控制台是否有 StoreKit 错误信息

### Q3: 如何测试不同地区的价格？

**方法 1 - 更改模拟器地区**：
1. 打开 **Settings** app（模拟器中）
2. **General** → **Language & Region**
3. 更改 **Region** 为目标地区
4. 重启应用

**方法 2 - 在 StoreKit Configuration 中切换**：
1. 打开 `.storekit` 文件
2. 在编辑器右上角选择 **"Editor"** → **"Default Storefront"**
3. 选择要测试的地区（如 China, United States）

### Q4: 真机测试时能用 StoreKit Configuration 吗？

**可以！** 但需要注意：
- 真机必须使用 **Sandbox 测试账号**
- 在 **Settings** → **App Store** → **Sandbox Account** 登录测试账号
- 或者在 Scheme 中启用 StoreKit Configuration（会覆盖真实的 App Store 连接）

---

## 下一步：提交到 App Store Connect

当测试完成后，要让真实用户能够购买：

1. **完成产品配置**：
   - 在 App Store Connect 中完善产品信息
   - 添加所有必需的本地化内容
   - 设置价格等级

2. **提交审核**：
   - 产品状态从"草稿"变为"准备提交"
   - 随应用一起提交审核
   - 审核通过后，产品会自动生效

3. **移除 StoreKit Configuration**（可选）：
   - 在 Scheme 中将 StoreKit Configuration 设为 "None"
   - 这样应用会连接真实的 App Store

---

## 调试技巧

### 查看 StoreKit 日志：

在 `UnlockAIPurchaseViewModel` 的 `loadProducts()` 方法中添加日志：

```swift
func loadProducts() async {
    print("🛒 开始加载产品...")
    do {
        let productIDs = PricingPlan.allCases.map { $0.productID }
        print("🛒 请求产品 IDs: \(productIDs)")
        
        let products = try await Product.products(for: productIDs)
        print("🛒 成功获取 \(products.count) 个产品")
        
        var map: [PricingPlan: Product] = [:]
        var priceMap: [PricingPlan: String] = [:]
        for product in products {
            print("🛒 产品: \(product.id) - \(product.displayName) - \(product.displayPrice)")
            if let plan = PricingPlan(productID: product.id) {
                map[plan] = product
                priceMap[plan] = product.displayPrice
            }
        }
        await MainActor.run {
            self.products = map
            self.prices = priceMap
            print("🛒 价格已更新: \(priceMap)")
        }
    } catch {
        print("❌ 加载产品失败: \(error)")
    }
}
```

运行后查看控制台输出，确认产品是否正确加载。

---

## 总结

使用 StoreKit Configuration File 的优势：

✅ **无需等待审核** - 立即测试内购功能  
✅ **本地测试** - 不依赖网络或 App Store 服务器  
✅ **多地区测试** - 轻松切换不同国家/地区  
✅ **完全控制** - 可以模拟各种购买场景  
✅ **安全** - 不会产生真实费用

现在就去创建你的 StoreKit Configuration File 吧！🚀

