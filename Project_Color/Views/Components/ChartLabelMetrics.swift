//
//  ChartLabelMetrics.swift
//  Project_Color
//
//  提供统一的标签尺寸度量，确保多个图表计算轴长一致
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ChartLabelMetrics {
    /// 使用 caption 字号的行高作为标签预留空间，保证 X/Y 轴长度一致
    static var captionLineHeight: CGFloat {
        #if canImport(UIKit)
        return UIFont.preferredFont(forTextStyle: .caption1).lineHeight
        #elseif canImport(AppKit)
        return NSFont.preferredFont(forTextStyle: .caption1).lineHeight
        #else
        return 12
        #endif
    }
}
