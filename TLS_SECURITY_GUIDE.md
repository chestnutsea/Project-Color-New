# TLS 证书验证安全指南

## 概述

本项目已实现严格的 TLS 证书验证，确保与 API 服务器的连接安全。

## 安全等级

### 开发环境（DEBUG）
- ✅ 标准证书验证（验证证书链和主机名）
- ⚠️ 允许受信任的自签名证书（Function Compute 等）
- 📝 详细的证书日志输出

### 生产环境（RELEASE）
- ✅ 严格的证书验证
- ✅ 完整的证书链验证
- ✅ 主机名匹配验证
- 🔒 可选的证书固定（Certificate Pinning）
- ❌ 拒绝所有自签名证书

## 配置文件

### TLSConfig.swift

```swift
// 1. 是否启用严格验证
static let strictValidation: Bool = true  // 生产环境推荐

// 2. 受信任的主机列表（仅开发环境）
static let trustedHosts: Set<String> = [
    ".fcapp.run",      // Aliyun Function Compute
    ".fc.aliyuncs.com",
    "localhost",
    "127.0.0.1"
]

// 3. 是否启用证书固定
static let enableCertificatePinning: Bool = false

// 4. 固定的证书公钥哈希
static let pinnedPublicKeyHashes: Set<String> = []
```

## 工作原理

### 1. 标准验证流程

```
1. 接收 TLS 挑战
   ↓
2. 验证主机名匹配
   ↓
3. 验证证书链有效性
   ↓
4. 检查证书是否过期
   ↓
5. 验证证书签发者
   ↓
6. 建立安全连接 ✅
```

### 2. 开发环境特殊处理

```
标准验证失败
   ↓
检查是否在受信任列表
   ↓
是 → 允许连接（记录警告）
否 → 拒绝连接 ❌
```

## 启用证书固定（高级安全）

### 什么是证书固定？

证书固定（Certificate Pinning）是一种额外的安全措施，将服务器的证书公钥哈希值预先存储在 App 中，连接时验证服务器证书是否匹配。

### 优点
- 🛡️ 防止中间人攻击
- 🔒 防止恶意 CA 签发伪造证书
- ✅ 更高的安全性

### 缺点
- ⚠️ 服务器更新证书时需要更新 App
- 📱 增加维护成本

### 如何启用

#### 步骤 1：获取服务器证书公钥哈希

```bash
# 方法 1：使用 openssl
openssl s_client -connect your-domain.com:443 < /dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64

# 方法 2：从 App 日志获取（运行一次 App，查看日志输出）
# 日志中会显示：📜 证书公钥哈希: XXXXXXXXXXXX
```

#### 步骤 2：配置哈希值

```swift
// TLSConfig.swift
static let enableCertificatePinning: Bool = true

static let pinnedPublicKeyHashes: Set<String> = [
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",  // 主证书
    "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="   // 备用证书
]
```

#### 步骤 3：测试

1. 运行 App
2. 查看日志输出
3. 确认显示 "✅ 证书固定验证通过"

## 添加新的受信任主机

### 开发环境

```swift
// TLSConfig.swift
static let trustedHosts: Set<String> = [
    ".fcapp.run",
    ".your-domain.com",  // 添加你的域名
    "api.example.com"    // 或具体的主机名
]
```

### 通配符规则

- `".fcapp.run"` → 匹配 `xxx.fcapp.run`、`yyy.fcapp.run`
- `"localhost"` → 仅匹配 `localhost`

## 故障排查

### 问题 1：TLS 连接失败

```
❌ TLS 证书验证失败
```

**解决方案：**
1. 检查服务器证书是否有效
2. 检查证书是否过期
3. 检查主机名是否匹配
4. 开发环境：添加主机到 `trustedHosts`

### 问题 2：证书固定失败

```
❌ 证书固定验证失败: 公钥哈希不匹配
```

**解决方案：**
1. 重新获取最新的证书公钥哈希
2. 更新 `pinnedPublicKeyHashes`
3. 确保哈希值正确（Base64 格式）

### 问题 3：开发环境无法连接

```
❌ 连接失败
```

**解决方案：**
1. 临时设置 `strictValidation = false`
2. 添加主机到 `trustedHosts`
3. 检查网络连接

## 日志说明

### 正常连接日志

```
🔐 开始验证 TLS 证书，主机: api.example.com
📜 证书链长度: 3
📜 证书 Common Name: api.example.com
📜 证书主题: api.example.com
✅ TLS 证书验证通过
```

### 开发环境日志

```
⚠️ 证书评估错误: ...
⚠️ 开发模式: 允许受信任的主机（xxx.fcapp.run）
✅ TLS 证书已接受
```

### 证书固定日志

```
📜 证书公钥哈希: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
✅ 证书固定验证通过
```

## 安全建议

### ✅ 推荐做法

1. **生产环境启用严格验证**
   ```swift
   static let strictValidation: Bool = true
   ```

2. **使用证书固定（可选）**
   - 适合对安全要求极高的场景
   - 需要定期更新证书哈希

3. **定期审查受信任主机列表**
   - 只保留必要的主机
   - 移除不再使用的主机

4. **监控证书过期时间**
   - 提前更新服务器证书
   - 避免证书过期导致连接失败

### ❌ 不推荐做法

1. **生产环境关闭严格验证**
   ```swift
   // ❌ 不要这样做
   static let strictValidation: Bool = false
   ```

2. **添加过多受信任主机**
   - 降低安全性
   - 增加攻击面

3. **使用通配符 `*` 信任所有主机**
   - 完全失去 TLS 保护
   - 极度危险

## 更多信息

### 相关文件
- `SSEClient.swift` - TLS 验证实现
- `TLSConfig.swift` - TLS 配置
- `APIConfig.swift` - API 配置

### 参考资料
- [Apple: URLSession TLS Requirements](https://developer.apple.com/documentation/foundation/url_loading_system)
- [OWASP: Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [RFC 5246: TLS Protocol](https://tools.ietf.org/html/rfc5246)

## 版本历史

- **v1.1** (2025-12-12): 添加严格的证书验证和证书固定支持
- **v1.0** (2025-12-12): 初始实现基础 TLS 验证
