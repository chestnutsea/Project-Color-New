//
//  UnlockAISheetView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/02/11.
//

import SwiftUI

private enum UnlockAIStyle {
    static let yellow = Color(red: 1.0, green: 0.9059, blue: 0.3059)
    static let green = Color(red: 0.6863, green: 0.8588, blue: 0.4275)
    static let cardBackground = Color(.systemGray6)
    
    enum Layout {
        static let rowSpacing: CGFloat = 8
        static let shapeIconHeight: CGFloat = 18
        static let proColumnRatio: CGFloat = 0.4
        static let pricingBorderWidth: CGFloat = 2
        static let footerTopSpacing: CGFloat = -8
    }

    enum PricingChina {
        static let monthly = "¥18.00"
        static let yearlyDiscount = "¥68.00"
        static let yearlyOriginal = "¥98.00"
        static let lifetimeDiscount = "¥198.00"
        static let lifetimeOriginal = "¥268.00"
    }

    enum PricingUS {
        static let monthly = "$2.99"
        static let yearlyDiscount = "$14.99"
        static let yearlyOriginal = "$19.99"
        static let lifetimeDiscount = "$39.99"
        static let lifetimeOriginal = "$49.99"
    }
}

struct UnlockAISheetView: View {
    var onClose: () -> Void = {}
    @State private var selectedPlan: PricingPlan = .monthly
    
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
                    
                    Text(L10n.UnlockAI.title.localized)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                    
                    benefitCard
                    
                    pricingSection
                    
                    upgradeButton
                    
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
            
            Button(action: {}) {
                Text(L10n.UnlockAI.restore.localized)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var benefitCard: some View {
        VStack(alignment: .leading, spacing: UnlockAIStyle.Layout.rowSpacing) {
            GeometryReader { geo in
                let proWidth = geo.size.width * UnlockAIStyle.Layout.proColumnRatio
                let otherWidth = max((geo.size.width - proWidth) / 2, 0)
                
                HStack(alignment: .center, spacing: 0) {
                    Text(L10n.UnlockAI.comparisonTitle.localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: otherWidth, alignment: .leading)
                    
                    Text(L10n.UnlockAI.planBasic.localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: otherWidth, alignment: .center)
                    
                    Text(L10n.UnlockAI.planPro.localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: proWidth, alignment: .center)
                }
            }
            .frame(height: 20)
            
            Divider()
            
            BenefitRow(
                title: L10n.UnlockAI.featureICloud.localized,
                basic: checkIcon,
                pro: checkIcon
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureComposition.localized,
                basic: checkIcon,
                pro: checkIcon
            )
            
            BenefitRow(
                title: L10n.UnlockAI.featureColorLookup.localized,
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
            
            BenefitRow(
                title: L10n.UnlockAI.featureShare.localized,
                basic: unavailableIcon,
                pro: checkIcon
            )
        }
        .padding(16)
        .background(UnlockAIStyle.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private var pricingSection: some View {
        HStack(spacing: 12) {
            PricingCard(
                title: L10n.UnlockAI.pricingMonthly.localized,
                price: regionPricing.monthly,
                originalPrice: nil,
                showBadge: false,
                isSelected: selectedPlan == .monthly,
                onTap: { selectedPlan = .monthly }
            )
            
            PricingCard(
                title: L10n.UnlockAI.pricingYearly.localized,
                price: regionPricing.yearlyDiscount,
                originalPrice: regionPricing.yearlyOriginal,
                showBadge: true,
                isSelected: selectedPlan == .yearly,
                onTap: { selectedPlan = .yearly }
            )
            
            PricingCard(
                title: L10n.UnlockAI.pricingLifetime.localized,
                price: regionPricing.lifetimeDiscount,
                originalPrice: regionPricing.lifetimeOriginal,
                showBadge: true,
                isSelected: selectedPlan == .lifetime,
                onTap: { selectedPlan = .lifetime }
            )
        }
    }
    
    private var upgradeButton: some View {
        Button(action: {}) {
            Text(L10n.UnlockAI.upgradeNow.localized)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.black)
        }
        .background(UnlockAIStyle.yellow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            Text(L10n.UnlockAI.privacyPolicy.localized)
            Text("|")
                .foregroundColor(.secondary)
            Text(L10n.UnlockAI.termsOfUse.localized)
        }
        .font(.footnote)
        .foregroundColor(.secondary)
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
        Text(text)
            .font(.subheadline)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
    }

    private var regionPricing: PricingValues {
        if Locale.current.region?.identifier == "US" || Locale.current.currency?.identifier == "USD" {
            return PricingValues(
                monthly: UnlockAIStyle.PricingUS.monthly,
                yearlyDiscount: UnlockAIStyle.PricingUS.yearlyDiscount,
                yearlyOriginal: UnlockAIStyle.PricingUS.yearlyOriginal,
                lifetimeDiscount: UnlockAIStyle.PricingUS.lifetimeDiscount,
                lifetimeOriginal: UnlockAIStyle.PricingUS.lifetimeOriginal
            )
        } else {
            return PricingValues(
                monthly: UnlockAIStyle.PricingChina.monthly,
                yearlyDiscount: UnlockAIStyle.PricingChina.yearlyDiscount,
                yearlyOriginal: UnlockAIStyle.PricingChina.yearlyOriginal,
                lifetimeDiscount: UnlockAIStyle.PricingChina.lifetimeDiscount,
                lifetimeOriginal: UnlockAIStyle.PricingChina.lifetimeOriginal
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
            
            HStack(alignment: .center, spacing: 0) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
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
                
                VStack(alignment: .leading, spacing: 10) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                
                if showBadge {
                    Text(L10n.UnlockAI.priceEarlyBird.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(UnlockAIStyle.yellow)
                        .clipShape(Capsule())
                        .offset(x: -10, y: 10)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 120)
    }
}

private struct PricingValues {
    let monthly: String
    let yearlyDiscount: String
    let yearlyOriginal: String
    let lifetimeDiscount: String
    let lifetimeOriginal: String
}

private enum PricingPlan {
    case monthly
    case yearly
    case lifetime
}

#Preview {
    UnlockAISheetView()
}
