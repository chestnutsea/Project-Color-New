//
//  SaturationBrightnessScatterView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/10.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SaturationBrightnessPoint: Identifiable {
    let id = UUID()
    let saturation: CGFloat   // 0 - 255 (y 轴)
    let brightness: CGFloat  // 0 - 255 (x 轴)
    let color: Color  // 照片的视觉代表色
}

struct SaturationBrightnessScatterView: View {
    private enum Layout {
        static var labelSpace: CGFloat { ChartLabelMetrics.captionLineHeight }  // 标签占用的高度/宽度
        static let axisLineWidth: CGFloat = 1.0
        static let gridLineWidth: CGFloat = 0.6
        static let gridSegments: Int = 4
        static let pointDiameter: CGFloat = 10
        static let pointOpacity: Double = 0.8  // 圆点透明度（布局常量）
        static let axisColor = Color.secondary.opacity(0.7)
        static let gridColor = Color.secondary.opacity(0.25)
        #if canImport(UIKit)
        static let background = Color(UIColor.systemBackground)
        #elseif canImport(AppKit)
        static let background = Color(NSColor.windowBackgroundColor)
        #else
        static let background = Color.white
        #endif
        static let maxValue: CGFloat = 255
    }
    
    var points: [SaturationBrightnessPoint]
    var fixedChartSize: CGFloat? = nil  // 外部传入的固定图表尺寸（包含标签）
    var labelSpaceOverride: CGFloat? = nil  // 允许外部控制标签占用空间（保持与卡片计算一致）
    
    private var resolvedLabelSpace: CGFloat {
        labelSpaceOverride ?? Layout.labelSpace
    }
    
    var body: some View {
        ZStack {
            if points.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
    }
    
    private var chartView: some View {
        GeometryReader { geometry in
            chartContent(geometry: geometry)
        }
        .frame(width: fixedChartSize, height: fixedChartSize)
    }
    
    @ViewBuilder
    private func chartContent(geometry: GeometryProxy) -> some View {
        // 图表总尺寸
        let chartSize: CGFloat = fixedChartSize ?? min(geometry.size.width, geometry.size.height)
        // 坐标轴长度 = 图表尺寸 - 标签空间
        let axisSize: CGFloat = max(chartSize - resolvedLabelSpace, 0)
        
        // 坐标轴区域（为左侧和底部的标签留空间）
        let chartRect = CGRect(
            x: resolvedLabelSpace,
            y: 0,
            width: axisSize,
            height: axisSize
        )
        
        ZStack {
            Canvas { context, size in
                let currentChartSize: CGFloat = fixedChartSize ?? min(size.width, size.height)
                let currentAxisSize: CGFloat = max(currentChartSize - resolvedLabelSpace, 0)
                
                let rect = CGRect(
                    x: resolvedLabelSpace,
                    y: 0,
                    width: currentAxisSize,
                    height: currentAxisSize
                )
                
                drawGrid(in: rect, context: &context)
                drawAxes(in: rect, context: &context)
                drawPoints(in: rect, context: &context, totalSize: chartSize)
            }
            
            // Y 轴标签：饱和度，旋转 -90 度
            Text(L10n.AnalysisResult.saturation.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(-90))
                .position(x: resolvedLabelSpace / 2, y: chartRect.midY)
            
            // X 轴标签：亮度
            Text(L10n.AnalysisResult.brightness.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .position(x: chartRect.midX, y: chartSize - resolvedLabelSpace / 2 + 5)
        }
    }
    
    private func drawGrid(in rect: CGRect, context: inout GraphicsContext) {
        // 去掉中间的网格线，只保留坐标轴
    }
    
    private func drawAxes(in rect: CGRect, context: inout GraphicsContext) {
        var path = Path()
        // X axis
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Y axis
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        
        context.stroke(path, with: .color(Layout.axisColor), lineWidth: Layout.axisLineWidth)
    }
    
    private func drawPoints(in rect: CGRect, context: inout GraphicsContext, totalSize: CGFloat = 300) {
        // 根据视图大小动态调整点的大小
        let scaleFactor = totalSize / 300.0
        let pointSize = Layout.pointDiameter * min(scaleFactor, 1.0)
        
        for point in points {
            let clampedSaturation = max(0, min(point.saturation, Layout.maxValue))
            let clampedBrightness = max(0, min(point.brightness, Layout.maxValue))
            
            // x 轴是亮度，y 轴是饱和度（调换后的顺序）
            let xRatio = clampedBrightness / Layout.maxValue
            let yRatio = clampedSaturation / Layout.maxValue
            
            let x = rect.minX + rect.width * xRatio
            let y = rect.maxY - rect.height * yRatio
            let ellipseRect = CGRect(
                x: x - pointSize / 2,
                y: y - pointSize / 2,
                width: pointSize,
                height: pointSize
            )
            
            let path = Path(ellipseIn: ellipseRect)
            
            // 使用照片的视觉代表色
            context.fill(
                path,
                with: .color(point.color.opacity(Layout.pointOpacity))
            )
        }
    }
    
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.scatter")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("暂无饱和度/亮度数据")
                .font(.headline)
            Text("完成色彩分析后将显示散点图。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

