//
//  SubscriptionManager.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/31.
//  订阅管理和使用限制
//

import Foundation
import StoreKit
import Combine

/// 订阅管理器 - 管理订阅状态和使用配额
final class SubscriptionManager: ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    
    @Published var isProUser: Bool = false
    @Published var isLifetimeUser: Bool = false  // 是否是终身会员
    @Published var currentMonthAnalysisCount: Int = 0
    @Published var canAnalyzeMore: Bool = true
    
    /// 会员类型
    enum MembershipType {
        case free
        case monthly
        case yearly
        case lifetime
        
        var displayName: String {
            switch self {
            case .free: return L10n.Membership.free.localized
            case .monthly: return L10n.Membership.monthly.localized
            case .yearly: return L10n.Membership.yearly.localized
            case .lifetime: return L10n.Membership.lifetime.localized
            }
        }
    }
    
    @Published var membershipType: MembershipType = .free
    
    // MARK: - Constants
    
    private enum Limits {
        static let freeMonthlyLimit = 3
        static let proMonthlyLimit = 100
    }
    
    private enum StorageKeys {
        static let analysisCount = "monthly_analysis_count"
        static let lastResetDate = "last_reset_date"
        static let hasUploadedFirstPhoto = "has_uploaded_first_photo"
        static let keychainMonthlyState = "monthly_usage_state"
    }
    
    private struct MonthlyState: Codable {
        var count: Int
        var lastResetDate: Date
        var hasUploadedFirstPhoto: Bool
    }
    
    // MARK: - Private Properties
    
    private var updateTask: Task<Void, Never>?
    private let userDefaults = UserDefaults.standard
    private var persistedState = MonthlyState(
        count: 0,
        lastResetDate: Date(),
        hasUploadedFirstPhoto: false
    )
    
    // MARK: - Initialization
    
    private init() {
        loadPersistedState()
        checkAndResetMonthlyCount()
        persistState()  // 确保 Keychain 与 UserDefaults 同步
        
        // 异步检查订阅状态和数据一致性
        Task {
            await checkSubscriptionStatus()
            await startListeningForTransactions()
            await checkDataConsistency()
        }
    }
    
    /// 检查数据一致性：如果 Core Data 为空但计数不为0，重置计数
    private func checkDataConsistency() async {
        // 如果计数为0，无需检查
        guard currentMonthAnalysisCount > 0 else { return }
        
        // 检查 Core Data 中是否有数据
        let photoCount = await CoreDataManager.shared.fetchTotalPhotoCount()
        // 保留计数，即便 Core Data 为空（例如重新安装后的首次启动）
        guard photoCount > 0 else { return }
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// 检查是否可以扫描指定数量的照片
    func canScanPhotos(count: Int) -> Bool {
        checkAndResetMonthlyCount()
        
        let limit = isProUser ? Limits.proMonthlyLimit : Limits.freeMonthlyLimit
        return currentMonthAnalysisCount + count <= limit
    }
    
    /// 获取剩余可扫描张数
    func remainingScanCount() -> Int {
        checkAndResetMonthlyCount()
        
        let limit = isProUser ? Limits.proMonthlyLimit : Limits.freeMonthlyLimit
        return max(0, limit - currentMonthAnalysisCount)
    }
    
    /// 记录扫描的照片数量（在扫描成功后调用）
    func recordScannedPhotos(count: Int) {
        checkAndResetMonthlyCount()
        
        persistedState.count += count
        if !persistedState.hasUploadedFirstPhoto {
            persistedState.hasUploadedFirstPhoto = true
            persistedState.lastResetDate = Date()
        } else if persistedState.lastResetDate > Date() {
            // 防止意外的未来日期导致重置逻辑失效
            persistedState.lastResetDate = Date()
        }
        persistState()
        
        updateCanAnalyzeMore()
        
        print("📊 [订阅] 已记录扫描 \(count) 张，本月已扫描: \(currentMonthAnalysisCount) 张")
    }
    
    /// 获取当前限制信息（已扫描张数 / 总张数）
    func getLimitInfo() -> (used: Int, total: Int, isUnlimited: Bool) {
        checkAndResetMonthlyCount()
        
        print("📊 [订阅] getLimitInfo - currentMonthAnalysisCount: \(currentMonthAnalysisCount), isProUser: \(isProUser)")
        
        if isProUser {
            return (currentMonthAnalysisCount, Limits.proMonthlyLimit, false)
        } else {
            return (currentMonthAnalysisCount, Limits.freeMonthlyLimit, false)
        }
    }
    
    /// 手动刷新订阅状态（用于购买后）
    func refreshSubscriptionStatus() async {
        await checkSubscriptionStatus()
    }
    
    // MARK: - Private Methods
    
    /// 检查订阅状态
    private func checkSubscriptionStatus() async {
        print("🔍 [订阅] 检查订阅状态...")
        
        // 检查是否有活跃的订阅或终身购买
        var hasActiveSubscription = false
        var hasLifetimePurchase = false
        var detectedMembershipType: MembershipType = .free
        
        // 检查所有交易
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // 检查产品 ID
            if transaction.productID == "Permanent_membership" {  // 终身购买
                hasActiveSubscription = true
                hasLifetimePurchase = true
                detectedMembershipType = .lifetime
                print("✅ [订阅] 找到终身购买: \(transaction.productID)")
                break
            } else if transaction.productID == "Monthly_membership" {  // 月度订阅
                hasActiveSubscription = true
                detectedMembershipType = .monthly
                print("✅ [订阅] 找到月度订阅: \(transaction.productID)")
            } else if transaction.productID == "Yearly_membership" {  // 年度订阅
                hasActiveSubscription = true
                detectedMembershipType = .yearly
                print("✅ [订阅] 找到年度订阅: \(transaction.productID)")
            }
        }
        
        await MainActor.run {
            self.isProUser = hasActiveSubscription
            self.isLifetimeUser = hasLifetimePurchase
            self.membershipType = detectedMembershipType
            self.updateCanAnalyzeMore()
            print("📱 [订阅] Pro 状态: \(hasActiveSubscription), 会员类型: \(detectedMembershipType.displayName)")
        }
    }
    
    /// 监听交易更新
    private func startListeningForTransactions() async {
        updateTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                if case .verified(let transaction) = result {
                    print("🔔 [订阅] 检测到交易更新: \(transaction.productID)")
                    await self.checkSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    /// 从 Keychain（优先）或 UserDefaults 载入计数
    private func loadPersistedState() {
        if let data = KeychainStore.shared.data(for: StorageKeys.keychainMonthlyState),
           let state = try? JSONDecoder().decode(MonthlyState.self, from: data) {
            persistedState = state
            currentMonthAnalysisCount = state.count
            print("📊 [订阅] 从 Keychain 读取计数: \(state.count)")
            return
        }
        
        let defaultsState = MonthlyState(
            count: userDefaults.integer(forKey: StorageKeys.analysisCount),
            lastResetDate: userDefaults.object(forKey: StorageKeys.lastResetDate) as? Date ?? Date(),
            hasUploadedFirstPhoto: userDefaults.bool(forKey: StorageKeys.hasUploadedFirstPhoto)
        )
        persistedState = defaultsState
        currentMonthAnalysisCount = defaultsState.count
        print("📊 [订阅] 从 UserDefaults 读取计数: \(defaultsState.count)")
    }
    
    /// 将状态写回 Keychain 和 UserDefaults
    private func persistState() {
        currentMonthAnalysisCount = persistedState.count
        persistToUserDefaults()
        persistToKeychain()
    }
    
    private func persistToUserDefaults() {
        userDefaults.set(persistedState.count, forKey: StorageKeys.analysisCount)
        userDefaults.set(persistedState.lastResetDate, forKey: StorageKeys.lastResetDate)
        userDefaults.set(persistedState.hasUploadedFirstPhoto, forKey: StorageKeys.hasUploadedFirstPhoto)
    }
    
    private func persistToKeychain() {
        guard let data = try? JSONEncoder().encode(persistedState) else {
            print("❌ [订阅] 无法编码月度状态，未写入 Keychain")
            return
        }
        if !KeychainStore.shared.set(data: data, for: StorageKeys.keychainMonthlyState) {
            print("⚠️ [订阅] 写入 Keychain 失败")
        }
    }
    
    /// 检查并重置月度计数
    private func checkAndResetMonthlyCount() {
        // 如果用户还没上传过第一张照片，不需要重置，但保持状态同步
        guard persistedState.hasUploadedFirstPhoto else {
            currentMonthAnalysisCount = 0
            persistState()
            print("📊 [订阅] 用户还没上传过照片，计数为 0")
            updateCanAnalyzeMore()
            return
        }
        
        let calendar = Calendar.current
        
        // 检查是否是新的月份
        if !calendar.isDate(persistedState.lastResetDate, equalTo: Date(), toGranularity: .month) {
            print("🔄 [订阅] 新月份，重置扫描张数")
            persistedState.count = 0
            persistedState.lastResetDate = Date()
            persistState()
        } else {
            currentMonthAnalysisCount = persistedState.count
            print("📊 [订阅] 计数未重置，当前: \(persistedState.count)")
        }
        
        updateCanAnalyzeMore()
    }
    
    /// 更新是否可以继续分析
    private func updateCanAnalyzeMore() {
        let limit = isProUser ? Limits.proMonthlyLimit : Limits.freeMonthlyLimit
        canAnalyzeMore = currentMonthAnalysisCount < limit
    }
}

// MARK: - Usage Limit Error

enum AnalysisLimitError: LocalizedError {
    case monthlyLimitReached
    
    var errorDescription: String? {
        switch self {
        case .monthlyLimitReached:
            return "本月分析次数已用完"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .monthlyLimitReached:
            return "升级到 Pro 版本可获得每月 100 次分析额度"
        }
    }
}
