//
//  UnlockAISheetView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/02/11.
//

import SwiftUI
import StoreKit
import Combine

private enum UnlockAIStyle {
    static let yellow = Color(red: 1.0, green: 0.9059, blue: 0.3059)
    static let green = Color(red: 0.6863, green: 0.8588, blue: 0.4275)
    static let cardBackground = Color(.systemGray6)
    
    enum Layout {
        static let rowSpacing: CGFloat = 8
        static let shapeIconHeight: CGFloat = 18
        static let proColumnRatio: CGFloat = 0.4
        static let pricingBorderWidth: CGFloat = 2
        static let footerTopSpacing: CGFloat = -8  // 负值用于减少与上方按钮的间距
    }

    enum PricingChina {
        static let monthly = "¥6.00"
        static let yearlyDiscount = "¥18.00"
        static let yearlyOriginal = "¥25.00"
        static let lifetimeDiscount = "¥38.00"
        static let lifetimeOriginal = "¥50.00"
    }

    enum PricingUS {
        static let monthly = "$0.99"
        static let yearlyDiscount = "$2.99"
        static let yearlyOriginal = "$4.99"
        static let lifetimeDiscount = "$5.99"
        static let lifetimeOriginal = "$7.99"
    }
}

struct UnlockAISheetView: View {
    var onClose: () -> Void = {}
    @StateObject private var purchaseVM = UnlockAIPurchaseViewModel()
    @State private var showRestoreSuccessAlert = false
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .padding(.top, 4)
                    
                    Text(purchaseVM.titleText)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    
                    benefitCard
                    
                    if purchaseVM.shouldShowPricing {
                    pricingSection
                    
                    upgradeButton
                    }
                    
                    footer
                        .padding(.top, UnlockAIStyle.Layout.footerTopSpacing)
                }
                .padding(.horizontal, 20)
                .padding(.top, topInset + 64)
                .padding(.bottom, 24 + proxy.safeAreaInsets.bottom)
            }
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea()
        .task {
            await purchaseVM.loadProducts()
        }
        .alert(L10n.UnlockAI.purchaseFailed.localized, isPresented: $purchaseVM.showFailureAlert) {
            Button(L10n.UnlockAI.ok.localized, role: .cancel) { }
        }
        .alert(L10n.UnlockAI.restoreSuccess.localized, isPresented: $showRestoreSuccessAlert) {
            Button(L10n.UnlockAI.ok.localized, role: .cancel) {
                onClose()
            }
        } message: {
            Text(L10n.UnlockAI.restoreSuccessMessage.localized)
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(8)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    let success = await purchaseVM.restorePurchases()
                    // 只有真正恢复成功才显示提示
                    if success {
                        showRestoreSuccessAlert = true
                    }
                    // 如果失败，ViewModel 会显示失败 alert
                }
            }) {
                Text(L10n.UnlockAI.restore.localized)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .disabled(purchaseVM.isProcessing)
        }
    }
    
    private var benefitCard: some View {
        VStack(alignment: .leading, spacing: UnlockAIStyle.Layout.rowSpacing) {
            GeometryReader { geo in
                let proWidth = geo.size.width * UnlockAIStyle.Layout.proColumnRatio
                let otherWidth = max((geo.size.width - proWidth) / 2, 0)
                
                // 根据语言环境决定标题行字体大小：中文用 subheadline，英文用 caption
                let isChinese = Locale.current.language.languageCode?.identifier == "zh"
                let headerFont: Font = isChinese ? .subheadline.weight(.semibold) : .caption.weight(.semibold)
                
                HStack(alignment: .center, spacing: 0) {
                    Text(L10n.UnlockAI.comparisonTitle.localized)
                        .font(headerFont)
                        .foregroundColor(.secondary)
                        .frame(width: otherWidth, alignment: .leading)
                    
                    Text(L10n.UnlockAI.planBasic.localized)
                        .font(headerFont)
                        .foregroundColor(.primary)
                        .frame(width: otherWidth, alignment: .center)
                    
                    Text(L10n.UnlockAI.planPro.localized)
                        .font(headerFont)
                        .foregroundColor(.primary)
                        .frame(width: proWidth, alignment: .center)
                }
            }
            .frame(minHeight: 30)
            
            BenefitRow(
                title: L10n.UnlockAI.featureColorSearch.localized,
                basic: checkIcon,
                pro: checkIcon
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureColorCalculation.localized,
                basic: checkIcon,
                pro: checkIcon
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureRefresh.localized,
                basic: valueLabel(L10n.UnlockAI.valueBasicRefresh.localized),
                pro: valueLabel(L10n.UnlockAI.valueProRefresh.localized)
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureDisplayMode.localized,
                basic: valueLabel(L10n.UnlockAI.valueBasicMode.localized),
                pro: valueLabel(L10n.UnlockAI.valueProMode.localized)
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureDisplayShape.localized,
                basic: Image("circle_blue")
                    .resizable()
                    .scaledToFit()
                    .frame(height: UnlockAIStyle.Layout.shapeIconHeight),
                pro: Image("shapes_grouped")
                    .resizable()
                    .scaledToFit()
                    .frame(height: UnlockAIStyle.Layout.shapeIconHeight)
            )
        }
        .padding(16)
        .background(UnlockAIStyle.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var pricingSection: some View {
        Group {
            if purchaseVM.shouldShowSubscriptions {
                // 免费用户：显示 3 个选项
        HStack(spacing: 12) {
            PricingCard(
                title: L10n.UnlockAI.pricingMonthly.localized,
                price: purchaseVM.displayPrice(for: .monthly, fallback: regionPricing.monthly),
                originalPrice: nil,
                showBadge: false,
                isSelected: purchaseVM.selectedPlan == .monthly,
                onTap: { purchaseVM.selectedPlan = .monthly }
            )
            
            PricingCard(
                title: L10n.UnlockAI.pricingYearly.localized,
                price: purchaseVM.displayPrice(for: .yearly, fallback: regionPricing.yearlyDiscount),
                originalPrice: nil,
                showBadge: true,
                isSelected: purchaseVM.selectedPlan == .yearly,
                onTap: { purchaseVM.selectedPlan = .yearly }
            )
            
            PricingCard(
                title: L10n.UnlockAI.pricingLifetime.localized,
                price: purchaseVM.displayPrice(for: .lifetime, fallback: regionPricing.lifetimeDiscount),
                originalPrice: nil,
                showBadge: true,
                isSelected: purchaseVM.selectedPlan == .lifetime,
                onTap: { purchaseVM.selectedPlan = .lifetime }
            )
                }
            } else {
                // 已购买用户：只显示永久购买（全宽）
                PricingCard(
                    title: L10n.UnlockAI.pricingLifetime.localized,
                    price: purchaseVM.displayPrice(for: .lifetime, fallback: regionPricing.lifetimeDiscount),
                    originalPrice: nil,
                    showBadge: true,
                    isSelected: purchaseVM.selectedPlan == .lifetime,
                    onTap: { purchaseVM.selectedPlan = .lifetime },
                    isFullWidth: true
                )
            }
        }
        .disabled(purchaseVM.isProcessing)
    }
    
    private var upgradeButton: some View {
        Button(action: {
            guard !purchaseVM.isProcessing else { return }
            Task {
                await purchaseVM.purchaseSelectedPlan()
            }
        }) {
            HStack(spacing: 8) {
                if purchaseVM.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(height: 16)
                }
                Text(purchaseVM.isProcessing ? L10n.UnlockAI.processing.localized : L10n.UnlockAI.upgradeNow.localized)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .background(UnlockAIStyle.yellow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .disabled(purchaseVM.isProcessing)
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                let urlString = LocalizationManager.shared.isChineseLanguage 
                    ? "https://www.yuque.com/deerhino/oi51m5/rzqhif0xn55r788n"
                    : "https://www.yuque.com/deerhino/oi51m5/gicclr4m62wsrb9r"
                if let url = URL(string: urlString) {
                    openURL(url)
                }
            } label: {
            Text(L10n.UnlockAI.privacyPolicy.localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Text("|")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Button {
                let urlString = LocalizationManager.shared.isChineseLanguage 
                    ? "https://www.yuque.com/deerhino/oi51m5/iv130myyrgko7fwk"
                    : "https://www.yuque.com/deerhino/oi51m5/iwrgdabsx5geh6yr"
                if let url = URL(string: urlString) {
                    openURL(url)
                }
            } label: {
            Text(L10n.UnlockAI.termsOfUse.localized)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var checkIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(UnlockAIStyle.green)
    }
    
    private var unavailableIcon: some View {
        Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.secondary)
    }
    
    private func valueLabel(_ text: String) -> some View {
        // 根据语言环境决定字体大小：中文用 subheadline，英文用 caption
        let isChinese = Locale.current.language.languageCode?.identifier == "zh"
        let valueFont: Font = isChinese ? .subheadline : .caption
        
        return Text(text)
            .font(valueFont)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var regionPricing: PricingValues {
        // 判断是否为中国区：检查地区标识符是否为 CN
        let isChinaRegion = Locale.current.region?.identifier == "CN"
        
        if isChinaRegion {
            return PricingValues(
                monthly: UnlockAIStyle.PricingChina.monthly,
                yearlyDiscount: UnlockAIStyle.PricingChina.yearlyDiscount,
                yearlyOriginal: UnlockAIStyle.PricingChina.yearlyOriginal,
                lifetimeDiscount: UnlockAIStyle.PricingChina.lifetimeDiscount,
                lifetimeOriginal: UnlockAIStyle.PricingChina.lifetimeOriginal
            )
        } else {
            return PricingValues(
                monthly: UnlockAIStyle.PricingUS.monthly,
                yearlyDiscount: UnlockAIStyle.PricingUS.yearlyDiscount,
                yearlyOriginal: UnlockAIStyle.PricingUS.yearlyOriginal,
                lifetimeDiscount: UnlockAIStyle.PricingUS.lifetimeDiscount,
                lifetimeOriginal: UnlockAIStyle.PricingUS.lifetimeOriginal
            )
        }
    }
}

private struct BenefitRow<Basic: View, Pro: View>: View {
    let title: String
    let basic: Basic
    let pro: Pro
    
    init(title: String, basic: Basic, pro: Pro) {
        self.title = title
        self.basic = basic
        self.pro = pro
    }
    
    var body: some View {
        GeometryReader { geo in
            let proWidth = geo.size.width * UnlockAIStyle.Layout.proColumnRatio
            let otherWidth = max((geo.size.width - proWidth) / 2, 0)
            
            // 根据语言环境决定字体大小：中文用 subheadline，英文用 caption
            let isChinese = Locale.current.language.languageCode?.identifier == "zh"
            let titleFont: Font = isChinese ? .subheadline : .caption
            
            HStack(alignment: .top, spacing: 0) {
                Text(title)
                    .font(titleFont)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: otherWidth, alignment: .leading)
                
                basic
                    .frame(width: otherWidth, alignment: .center)
                
                pro
                    .frame(width: proWidth, alignment: .center)
                    .layoutPriority(1)
            }
        }
        .frame(minHeight: 32)
    }
}

private struct PricingCard: View {
    let title: String
    let price: String
    let originalPrice: String?
    let showBadge: Bool
    let isSelected: Bool
    let onTap: () -> Void
    var isFullWidth: Bool = false  // 新增：是否全宽显示
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? UnlockAIStyle.yellow : Color.clear, lineWidth: UnlockAIStyle.Layout.pricingBorderWidth)
                    )
                
                VStack(alignment: isFullWidth ? .center : .leading, spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(price)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    if let originalPrice = originalPrice {
                        Text(originalPrice)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .strikethrough(true, color: .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: isFullWidth ? .center : .leading)
                .padding(isFullWidth ? 10 : 14)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 40)  // 价格卡片高度
    }
}

private struct PricingValues {
    let monthly: String
    let yearlyDiscount: String
    let yearlyOriginal: String
    let lifetimeDiscount: String
    let lifetimeOriginal: String
}

private enum PricingPlan: String, CaseIterable {
    case monthly = "Monthly_membership"
    case yearly = "Yearly_membership"
    case lifetime = "Permanent_membership"
    
    var productID: String { rawValue }
    
    init?(productID: String) {
        self.init(rawValue: productID)
    }
}

private final class UnlockAIPurchaseViewModel: ObservableObject {
    @Published var selectedPlan: PricingPlan = .monthly
    @Published var isProcessing: Bool = false
    @Published var showFailureAlert: Bool = false
    
    @Published private var products: [PricingPlan: Product] = [:]
    @Published private var prices: [PricingPlan: String] = [:]
    
    init() {
        // 如果已经是订阅用户，默认选中终身购买
        if SubscriptionManager.shared.isProUser && !SubscriptionManager.shared.isLifetimeUser {
            selectedPlan = .lifetime
        }
    }
    
    /// 检查是否是终身会员
    private var isLifetimeUser: Bool {
        return SubscriptionManager.shared.isLifetimeUser
    }
    
    /// 动态标题文本
    var titleText: String {
        if isLifetimeUser {
            return L10n.UnlockAI.titleLifetimeMember.localized
        } else if SubscriptionManager.shared.isProUser {
            return L10n.UnlockAI.titleProMember.localized
        } else {
            return L10n.UnlockAI.titleUpgrade.localized
        }
    }
    
    /// 是否显示订阅选项（月度/年度）
    var shouldShowSubscriptions: Bool {
        return !SubscriptionManager.shared.isProUser
    }
    
    /// 是否显示价格和升级按钮（终身会员不显示）
    var shouldShowPricing: Bool {
        return !isLifetimeUser
    }
    
    func loadProducts() async {
        print("🛒 [IAP] 开始加载产品...")
        do {
            let productIDs = PricingPlan.allCases.map { $0.productID }
            print("🛒 [IAP] 请求产品 IDs: \(productIDs)")
            
            let products = try await Product.products(for: productIDs)
            print("🛒 [IAP] 成功获取 \(products.count) 个产品")
            
            if products.isEmpty {
                print("⚠️ [IAP] 警告：未找到任何产品！")
                print("⚠️ [IAP] 可能原因：")
                print("   1. App Store Connect 中未配置这些 Product ID")
                print("   2. 产品未通过审核")
                print("   3. 产品在当前商店不可用")
                print("   4. 网络连接问题")
            }
            
            var map: [PricingPlan: Product] = [:]
            var priceMap: [PricingPlan: String] = [:]
            for product in products {
                print("🛒 [IAP] 产品详情:")
                print("   - ID: \(product.id)")
                print("   - 名称: \(product.displayName)")
                print("   - 价格: \(product.displayPrice)")
                print("   - 类型: \(product.type)")
                
                if let plan = PricingPlan(productID: product.id) {
                    map[plan] = product
                    priceMap[plan] = product.displayPrice
                } else {
                    print("⚠️ [IAP] 警告：产品 ID \(product.id) 无法映射到 PricingPlan")
                }
            }
            await MainActor.run {
                self.products = map
                self.prices = priceMap
                print("🛒 [IAP] 价格已更新: \(priceMap)")
                
                // 检查是否所有计划都有对应的产品
                for plan in PricingPlan.allCases {
                    if map[plan] == nil {
                        print("⚠️ [IAP] 警告：未找到 \(plan.productID) 的产品")
                    }
                }
            }
        } catch {
            print("❌ [IAP] 加载产品失败: \(error)")
            print("❌ [IAP] 错误类型: \(type(of: error))")
            print("❌ [IAP] 错误描述: \(error.localizedDescription)")
            
            if let storeError = error as? StoreKitError {
                print("❌ [IAP] StoreKit 错误: \(storeError)")
            }
        }
    }
    
    func displayPrice(for plan: PricingPlan, fallback: String) -> String {
        prices[plan] ?? fallback
    }
    
    func displayOriginalPrice(for plan: PricingPlan, fallback: String) -> String? {
        // If we have live StoreKit pricing, we don't show a made-up strike price.
        guard prices[plan] == nil else { return nil }
        return plan == .monthly ? nil : fallback
    }
    
    func purchaseSelectedPlan() async {
        await purchase(plan: selectedPlan)
    }
    
    func restorePurchases() async -> Bool {
        print("🔄 [IAP] 开始恢复购买...")
        await MainActor.run { isProcessing = true }
        
        do {
            try await AppStore.sync()
            print("✅ [IAP] AppStore.sync() 完成")
            
            // 等待一下让交易同步完成
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 刷新订阅状态
            await SubscriptionManager.shared.refreshSubscriptionStatus()
            
            // 再等待一下确保状态更新
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
            
            // 检查是否有有效订阅
            let hasSubscription = SubscriptionManager.shared.isProUser
            
            await MainActor.run { 
                isProcessing = false
            }
            
            print("📱 [IAP] 恢复购买结果: \(hasSubscription ? "成功" : "未找到购买记录")")
            
            // 如果没有找到订阅，也不显示失败（可能是用户取消登录）
            // 只有在真正出错时才显示失败
            return hasSubscription
            
        } catch {
            print("❌ [IAP] 恢复购买失败: \(error)")
            print("❌ [IAP] 错误详情: \(error.localizedDescription)")
            
            // 检查是否是用户取消
            let errorCode = (error as NSError).code
            if errorCode == 2 { // SKErrorPaymentCancelled
                print("⚠️ [IAP] 用户取消恢复购买")
                await MainActor.run {
                    isProcessing = false
                }
                return false
            }
            
            await MainActor.run {
                isProcessing = false
                showFailureAlert = true
            }
            return false
        }
    }
    
    private func purchase(plan: PricingPlan) async {
        print("💳 [IAP] 开始购买流程，计划: \(plan.productID)")
        
        guard let product = products[plan] else {
            print("❌ [IAP] 产品未找到: \(plan.productID)")
            print("❌ [IAP] 当前可用产品: \(products.keys.map { $0.productID })")
            await MainActor.run {
                showFailureAlert = true
            }
            return
        }
        
        print("💳 [IAP] 找到产品: \(product.displayName) - \(product.displayPrice)")
        await MainActor.run { isProcessing = true }
        
        do {
            print("💳 [IAP] 调用 product.purchase()...")
            let result = try await product.purchase()
            print("💳 [IAP] purchase() 返回结果: \(result)")
            
            switch result {
            case .success(let verification):
                print("✅ [IAP] 购买成功，开始验证...")
                switch verification {
                case .verified(let transaction):
                    print("✅ [IAP] 交易验证成功: \(transaction.id)")
                    print("✅ [IAP] 产品 ID: \(transaction.productID)")
                    print("✅ [IAP] 购买日期: \(transaction.purchaseDate)")
                    await transaction.finish()
                    print("✅ [IAP] 交易已完成")
                    
                    // ✅ 刷新订阅状态
                    await SubscriptionManager.shared.refreshSubscriptionStatus()
                case .unverified(let transaction, let error):
                    print("❌ [IAP] 交易验证失败: \(error)")
                    print("❌ [IAP] 未验证的交易: \(transaction)")
                    throw PurchaseError.unverified
                }
                await MainActor.run { isProcessing = false }
            case .userCancelled:
                print("⚠️ [IAP] 用户取消购买")
                await MainActor.run { isProcessing = false }
            case .pending:
                print("⏳ [IAP] 购买待处理（需要家长批准等）")
                await MainActor.run { isProcessing = false }
            @unknown default:
                print("❌ [IAP] 未知的购买结果")
                await MainActor.run {
                    isProcessing = false
                    showFailureAlert = true
                }
            }
        } catch {
            print("❌ [IAP] 购买过程出错: \(error)")
            print("❌ [IAP] 错误类型: \(type(of: error))")
            print("❌ [IAP] 错误描述: \(error.localizedDescription)")
            
            // 详细的错误信息
            if let storeError = error as? StoreKitError {
                print("❌ [IAP] StoreKit 错误代码: \(storeError)")
                switch storeError {
                case .userCancelled:
                    print("⚠️ [IAP] 用户取消")
                case .networkError(let underlyingError):
                    print("❌ [IAP] 网络错误: \(underlyingError)")
                case .systemError(let underlyingError):
                    print("❌ [IAP] 系统错误: \(underlyingError)")
                case .notAvailableInStorefront:
                    print("❌ [IAP] 产品在当前商店不可用")
                case .notEntitled:
                    print("❌ [IAP] 未授权")
                @unknown default:
                    print("❌ [IAP] 未知 StoreKit 错误")
                }
            }
            
            let nsError = error as NSError
            print("❌ [IAP] NSError domain: \(nsError.domain)")
            print("❌ [IAP] NSError code: \(nsError.code)")
            print("❌ [IAP] NSError userInfo: \(nsError.userInfo)")
            
            await MainActor.run {
                isProcessing = false
                showFailureAlert = true
            }
        }
    }
    
    private enum PurchaseError: Error {
        case unverified
    }
}

#Preview {
    UnlockAISheetView()
}
