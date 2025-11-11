//
//  PhotoStackView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/11.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

/// 可复用的照片堆组件
/// 根据传入的图片数量（1-3张）自动展示不同的堆叠样式
struct PhotoStackView: View {
    // MARK: - 布局常量
    private let photoCardWidth: CGFloat = 150
    private let cardCornerRadius: CGFloat = 6
    private let shadowColor = Color.black.opacity(0.25)
    private let shadowRadius: CGFloat = 12
    private let shadowOffsetX: CGFloat = 4
    private let shadowOffsetY: CGFloat = 6
    private let middleAngles: [Double] = [-6, 6]
    private let middleOffsetsX: [CGFloat] = [-25, 25]
    private let bottomAngles: [Double] = [-8, 6, -4]
    private let bottomOffsetsX: [CGFloat] = [-35, 35, -10]
    private let bottomOffsetsY: [CGFloat] = [0, 20, 40]
    
    // MARK: - Properties
    let images: [UIImage]
    
    // MARK: - Body
    var body: some View {
        switch images.count {
        case 1:
            singleCardSection()
        case 2:
            doubleCardSection()
        default:
            tripleCardSection()
        }
    }
    
    // MARK: - 单张卡片
    private func singleCardSection() -> some View {
        ZStack {
            if let image = images.first {
                let aspectRatio = image.size.width / image.size.height
                let imageHeight = photoCardWidth / aspectRatio
                
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                        .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                        .frame(width: photoCardWidth)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .frame(width: photoCardWidth, height: imageHeight)
            } else {
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: photoCardWidth, height: photoCardWidth * 4 / 3)
            }
        }
    }
    
    // MARK: - 两张卡片
    private func doubleCardSection() -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                if i < images.count {
                    let image = images[i]
                    let aspectRatio = image.size.width / image.size.height
                    let imageHeight = photoCardWidth / aspectRatio
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: photoCardWidth)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: photoCardWidth, height: imageHeight)
                    .rotationEffect(.degrees(middleAngles[i]))
                    .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardWidth, height: photoCardWidth * 4 / 3)
                        .rotationEffect(.degrees(middleAngles[i]))
                        .offset(x: middleOffsetsX[i], y: CGFloat(i) * 5)
                }
            }
        }
    }
    
    // MARK: - 三张卡片
    private func tripleCardSection() -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                if i < images.count {
                    let image = images[i]
                    let aspectRatio = image.size.width / image.size.height
                    let imageHeight = photoCardWidth / aspectRatio
                    
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
                            .shadow(color: shadowColor, radius: shadowRadius, x: shadowOffsetX, y: shadowOffsetY)
                            .frame(width: photoCardWidth)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                    .frame(width: photoCardWidth, height: imageHeight)
                    .rotationEffect(.degrees(bottomAngles[i]))
                    .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
                } else {
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: photoCardWidth, height: photoCardWidth * 4 / 3)
                        .rotationEffect(.degrees(bottomAngles[i]))
                        .offset(x: bottomOffsetsX[i], y: bottomOffsetsY[i])
                }
            }
        }
    }
}

#else

import SwiftUI

struct PhotoStackView: View {
    let images: [Any] = []
    
    var body: some View {
        Text("照片堆功能仅在 iOS 上可用")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

#endif
