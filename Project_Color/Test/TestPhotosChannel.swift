//
//  TestPhotosInjection.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI

struct PhotoTemplateView: View {
    // MARK: - 布局常量
    private let cardAspectRatio: CGFloat = 3.0 / 4.0
    
    // 每组卡片整体高度
    private let singleSectionHeight: CGFloat = 140
    private let doubleSectionHeight: CGFloat = 140
    private let tripleSectionHeight: CGFloat = 140
    
    // 卡片样式
    private let cardCornerRadius: CGFloat = 20
    private let cardColor = Color.gray
    
    // 阴影样式
    private let shadowColor = Color.black.opacity(0.25)
    private let shadowRadius: CGFloat = 12
    private let shadowOffsetX: CGFloat = 4
    private let shadowOffsetY: CGFloat = 6
    
    // MARK: - 卡片偏移与角度
    private let middleAngles: [Double] = [-6, 6]
    private let middleOffsetsX: [CGFloat] = [-25, 25]
    
    // 改进后的三张卡片参数：左 → 右 → 左，但第三张略上移以避免重叠
    private let bottomAngles: [Double] = [-8, 6, -4]
    private let bottomOffsetsX: [CGFloat] = [-35, 35, -10]
    private let bottomOffsetsY: [CGFloat] = [0, 20, 40] // 逐张上移
    
    var body: some View {
        VStack(spacing: 50) {
            // MARK: - 上：单张卡片
            singleCardSection()
            
            // MARK: - 中：两张卡片
            doubleCardSection()
            
            // MARK: - 下：三张卡片（左右交错展开）
            tripleCardSection()
        }
        .padding(.vertical, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - 单张卡片
    private func singleCardSection() -> some View {
        RoundedRectangle(cornerRadius: cardCornerRadius)
            .fill(cardColor)
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .shadow(color: shadowColor,
                    radius: shadowRadius,
                    x: shadowOffsetX,
                    y: shadowOffsetY)
            .frame(height: singleSectionHeight)
    }
    
    // MARK: - 两张卡片
    private func doubleCardSection() -> some View {
        ZStack {
            ForEach(0..<2) { i in
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(cardColor)
                    .aspectRatio(cardAspectRatio, contentMode: .fit)
                    .shadow(color: shadowColor,
                            radius: shadowRadius,
                            x: shadowOffsetX,
                            y: shadowOffsetY)
                    .rotationEffect(.degrees(middleAngles[i]))
                    .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
            }
        }
        .frame(height:doubleSectionHeight)
    }
    
    // MARK: - 三张卡片（左右交错）
    private func tripleCardSection() -> some View {
        ZStack {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(cardColor)
                    .aspectRatio(cardAspectRatio, contentMode: .fit)
                    .shadow(color: shadowColor,
                            radius: shadowRadius,
                            x: shadowOffsetX,
                            y: shadowOffsetY)
                    .rotationEffect(.degrees(bottomAngles[i]))
                    .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
            }
        }
        .frame(height: tripleSectionHeight)
    }
}

#Preview {
    PhotoTemplateView()
        .previewLayout(.sizeThatFits)
        .padding()
}
