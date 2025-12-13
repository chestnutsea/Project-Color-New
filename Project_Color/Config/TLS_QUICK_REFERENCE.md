# TLS 配置快速参考

## 🚀 快速开始

### 开发环境配置

1. 打开 `TLSConfig.swift`
2. 确认设置：
   ```swift
   static let strictValidation: Bool = false  // 开发环境
   ```
3. 运行 App

### 生产环境配置

1. 打开 `TLSConfig.swift`
2. 确认设置：
   ```swift
   static let strictValidation: Bool = true   // 生产环境
   ```
3. 构建 Release 版本

## 🔧 常见任务

### 添加新的受信任主机

```swift
// TLSConfig.swift
static let trustedHosts: Set<String> = [
    ".fcapp.run",
    ".your-new-domain.com",  // 👈 添加这里
]
```

### 启用证书固定

```bash
# 1. 获取证书哈希
openssl s_client -connect your-domain.com:443 < /dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  openssl enc -base64

# 2. 复制输出的哈希值
```

```swift
// TLSConfig.swift
static let enableCertificatePinning: Bool = true
static let pinnedPublicKeyHashes: Set<String> = [
    "你的哈希值",  // 👈 粘贴这里
]
```

## 📊 日志关键词

| 日志 | 含义 |
|------|------|
| `✅ TLS 证书验证通过` | 连接安全 |
| `⚠️ 开发模式: 允许受信任的主机` | 使用了自签名证书 |
| `❌ TLS 证书验证失败` | 证书无效，连接被拒绝 |
| `📜 证书公钥哈希: XXX` | 用于配置证书固定 |

## 🐛 故障排查

### TLS 连接失败？

```swift
// 临时解决（仅开发）
static let strictValidation: Bool = false
```

### 添加主机到受信任列表

```swift
static let trustedHosts: Set<String> = [
    ".fcapp.run",
    "your-host.com",  // 添加失败的主机
]
```

### 查看证书信息

运行 App，查看日志中的：
- `📜 证书 Common Name: XXX`
- `📜 证书主题: XXX`
- `📜 证书公钥哈希: XXX`

## ⚠️ 安全提醒

- ❌ 不要在生产环境关闭严格验证
- ❌ 不要添加不信任的主机
- ✅ 定期审查受信任主机列表
- ✅ 使用证书固定增强安全性
