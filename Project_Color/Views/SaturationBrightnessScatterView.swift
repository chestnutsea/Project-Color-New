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
    let saturation: CGFloat   // 0 - 255
    let brightness: CGFloat  // 0 - 255
}

struct SaturationBrightnessScatterView: View {
    private enum Layout {
        static let inset: CGFloat = 48
        static let axisLineWidth: CGFloat = 1.0
        static let gridLineWidth: CGFloat = 0.6
        static let gridSegments: Int = 4
        static let pointDiameter: CGFloat = 10
        static let pointOpacity: Double = 0.35
        static let axisColor = Color.secondary.opacity(0.7)
        static let gridColor = Color.secondary.opacity(0.25)
        #if canImport(UIKit)
        static let background = Color(UIColor.systemBackground)
        #elseif canImport(AppKit)
        static let background = Color(NSColor.windowBackgroundColor)
        #else
        static let background = Color.white
        #endif
        static let chartHeight: CGFloat = 320
        static let maxValue: CGFloat = 255
    }
    
    var points: [SaturationBrightnessPoint]
    var hue: Double?
    
    var body: some View {
        ZStack {
            if points.isEmpty {
                emptyState
            } else {
                chartView
            }
        }
        .frame(height: Layout.chartHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Layout.background)
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        )
    }
    
    private var chartView: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let chartRect = CGRect(
                    x: Layout.inset,
                    y: Layout.inset,
                    width: size.width - Layout.inset * 2,
                    height: size.height - Layout.inset * 2
                )
                
                drawGrid(in: chartRect, context: &context)
                drawAxes(in: chartRect, context: &context)
                drawTicks(in: chartRect, context: &context)
                drawPoints(in: chartRect, context: &context)
                drawAxisTitles(in: chartRect, context: &context)
            }
        }
    }
    
    private func drawGrid(in rect: CGRect, context: inout GraphicsContext) {
        guard Layout.gridSegments > 0 else { return }
        
        let step = rect.width / CGFloat(Layout.gridSegments)
        for index in 1..<Layout.gridSegments {
            let x = rect.minX + CGFloat(index) * step
            var path = Path()
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.stroke(path, with: .color(Layout.gridColor), lineWidth: Layout.gridLineWidth)
        }
        
        let verticalStep = rect.height / CGFloat(Layout.gridSegments)
        for index in 1..<Layout.gridSegments {
            let y = rect.minY + CGFloat(index) * verticalStep
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.stroke(path, with: .color(Layout.gridColor), lineWidth: Layout.gridLineWidth)
        }
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
    
    private func drawTicks(in rect: CGRect, context: inout GraphicsContext) {
        let tickValues: [CGFloat] = [0, 64, 128, 192, 255]
        for value in tickValues {
            // Horizontal ticks (X-axis)
            let x = rect.minX + rect.width * (value / Layout.maxValue)
            var tickPath = Path()
            tickPath.move(to: CGPoint(x: x, y: rect.maxY))
            tickPath.addLine(to: CGPoint(x: x, y: rect.maxY + 6))
            context.stroke(tickPath, with: .color(Layout.axisColor), lineWidth: Layout.axisLineWidth)
            
            let label = Text("\(Int(value))").font(.caption2)
            context.draw(label, at: CGPoint(x: x, y: rect.maxY + 14), anchor: .top)
            
            // Vertical ticks (Y-axis)
            let y = rect.maxY - rect.height * (value / Layout.maxValue)
            var yTickPath = Path()
            yTickPath.move(to: CGPoint(x: rect.minX, y: y))
            yTickPath.addLine(to: CGPoint(x: rect.minX - 6, y: y))
            context.stroke(yTickPath, with: .color(Layout.axisColor), lineWidth: Layout.axisLineWidth)
            
            if value != 0 { // avoid duplicate zero at origin
                let yLabel = Text("\(Int(value))").font(.caption2)
                context.draw(yLabel, at: CGPoint(x: rect.minX - 10, y: y), anchor: .trailing)
            }
        }
        
        // Origin label
        let zeroLabel = Text("0").font(.caption2)
        context.draw(zeroLabel, at: CGPoint(x: rect.minX - 8, y: rect.maxY + 14), anchor: .topTrailing)
    }
    
    private func drawPoints(in rect: CGRect, context: inout GraphicsContext) {
        for point in points {
            let clampedSaturation = max(0, min(point.saturation, Layout.maxValue))
            let clampedBrightness = max(0, min(point.brightness, Layout.maxValue))
            
            let xRatio = clampedSaturation / Layout.maxValue
            let yRatio = clampedBrightness / Layout.maxValue
            
            let x = rect.minX + rect.width * xRatio
            let y = rect.maxY - rect.height * yRatio
            let ellipseRect = CGRect(
                x: x - Layout.pointDiameter / 2,
                y: y - Layout.pointDiameter / 2,
                width: Layout.pointDiameter,
                height: Layout.pointDiameter
            )
            
            let path = Path(ellipseIn: ellipseRect)
            
            let hueValue = hue ?? 0.6
            let saturationComponent = xRatio
            let brightnessComponent = max(0.02, yRatio)
            let pointColor = Color(
                hue: hueValue,
                saturation: saturationComponent,
                brightness: brightnessComponent
            )
            
            context.fill(
                path,
                with: .color(pointColor.opacity(Layout.pointOpacity))
            )
        }
    }
    
    private func drawAxisTitles(in rect: CGRect, context: inout GraphicsContext) {
        let saturationTitle = Text("饱和度 (S)").font(.caption).foregroundColor(.secondary)
        context.draw(
            saturationTitle,
            at: CGPoint(x: rect.midX, y: rect.maxY + 32),
            anchor: .top
        )
        
        let brightnessTitle = Text("亮度 (V)").font(.caption).foregroundColor(.secondary)
        context.draw(
            brightnessTitle,
            at: CGPoint(x: rect.minX - 36, y: rect.midY),
            anchor: .center
        )
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


