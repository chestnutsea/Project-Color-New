//
//  GardenView.swift
//  Project_Color
//
//  花园模式视图
//  包含花朵布局、动画、天气信息显示
//

import SwiftUI
import Photos

// MARK: - 共享数据结构（与 EmergeView.ViewModel 保持一致）

/// 颜色圆形数据（用于 Garden 视图）
struct GardenColorCircle: Identifiable {
    let id: UUID
    let color: Color
    let photoCount: Int
    var position: CGPoint
    var radius: CGFloat
    var photos: [GardenPhotoInfo]
    var rotation: Angle
}

/// 照片信息（用于 Garden 视图）
struct GardenPhotoInfo: Identifiable {
    let assetIdentifier: String
    let distance: Float
    var id: String { assetIdentifier }
}

// MARK: - 花园模式参数

private enum GardenFlowerLayout {
    static let petalCount: Int = 5             // 固定 5 瓣
    static let stemHeightRatio: CGFloat = 0.98 // 茎的高度占完整高度的比例
    static let growDuration: TimeInterval = 2.5 // 生长动画时长
    static let swayAmplitude: CGFloat = 20     // 摇曳幅度
    static let swaySpeed: Double = 1.0         // 摇曳速度
    
    // 花瓣大小范围（与圆形 radius 映射一致，实际花朵直径 = radius * 2）
    static let minFlowerRadius: CGFloat = 5   // 最小花朵半径（对应最少照片数）
    static let maxFlowerRadius: CGFloat = 15   // 最大花朵半径（对应最多照片数）
}

// MARK: - 花园视图主体

struct GardenFlowerView: View {
    
    // 从父视图传入的数据
    let colorCircles: [GardenColorCircle]
    let screenSize: CGSize
    
    // 选中状态的回调
    let onFlowerTapped: (UUID, CGPoint, CGFloat, Color, [GardenPhotoInfo]) -> Void
    
    // 内部状态
    @State private var gardenStartTime: Date? = nil
    @State private var gardenFlowerHeights: [UUID: CGFloat] = [:]
    @State private var gardenFlowerPositions: [UUID: CGFloat] = [:]
    
    // 天气信息
    @StateObject private var weatherService = LocationWeatherService.shared
    @State private var weatherInfo: LocationWeatherInfo?
    @State private var isLoadingWeather = false
    
    var body: some View {
        ZStack {
            // 花朵绘制层
            TimelineView(.animation) { timeline in
                let startTime = gardenStartTime ?? Date()
                let t = timeline.date.timeIntervalSince(startTime)
                
                Canvas { context, size in
                    let groundY = size.height  // 茎的底部在屏幕最底部
                    let circles = colorCircles.sorted(by: { $0.id.uuidString < $1.id.uuidString })
                    
                    for (index, circle) in circles.enumerated() {
                        drawGardenFlower(
                            context: &context,
                            size: size,
                            time: t,
                            groundY: groundY,
                            circle: circle,
                            index: index,
                            total: circles.count
                        )
                    }
                }
            }
            
            // 点击检测层
            ForEach(colorCircles) { circle in
                let sortedCircles = colorCircles.sorted(by: { $0.id.uuidString < $1.id.uuidString })
                if let index = sortedCircles.firstIndex(where: { $0.id == circle.id }) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // 在点击时计算所有值，确保使用正确的 circle
                            let x = calculateGardenFlowerX(circleId: circle.id, screenWidth: screenSize.width)
                            let flowerHeight = gardenFlowerHeights[circle.id] ?? 0
                            let flowerSize = calculateGardenFlowerSize(photoCount: circle.photoCount)
                            let flowerTopY = screenSize.height - flowerHeight
                            
                            onFlowerTapped(
                                circle.id,
                                CGPoint(x: x, y: flowerTopY),
                                flowerSize / 2,
                                circle.color,
                                circle.photos
                            )
                        }
                        .frame(
                            width: {
                                let flowerSize = calculateGardenFlowerSize(photoCount: circle.photoCount)
                                return max(flowerSize * 2, 60.0)
                            }(),
                            height: {
                                let flowerHeight = gardenFlowerHeights[circle.id] ?? 0
                                let flowerSize = calculateGardenFlowerSize(photoCount: circle.photoCount)
                                return max(flowerHeight + flowerSize, 100.0)
                            }()
                        )
                        .position(
                            x: calculateGardenFlowerX(circleId: circle.id, screenWidth: screenSize.width),
                            y: {
                                let flowerHeight = gardenFlowerHeights[circle.id] ?? 0
                                let flowerSize = calculateGardenFlowerSize(photoCount: circle.photoCount)
                                let hitAreaHeight = max(flowerHeight + flowerSize, 100.0)
                                return screenSize.height - hitAreaHeight / 2
                            }()
                        )
                }
            }
            
            // 天气信息显示（左上角）
            if let weather = weatherInfo {
                VStack {
                    HStack {
                        WeatherInfoView(weatherInfo: weather)
                            .padding(.leading, 16)
                            .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            // 初始化花园状态
            if gardenStartTime == nil {
                gardenStartTime = Date()
                
                // 预先生成所有花朵的高度和位置，避免后续重新计算
                for circle in colorCircles {
                    if gardenFlowerHeights[circle.id] == nil {
                        let minHeight = screenSize.height * 0.25
                        let maxHeight = screenSize.height * (2.0/3.0)
                        gardenFlowerHeights[circle.id] = CGFloat.random(in: minHeight...maxHeight)
                    }
                    
                    if gardenFlowerPositions[circle.id] == nil {
                        let leftBound = screenSize.width / 5
                        let rightBound = screenSize.width * 4 / 5
                        gardenFlowerPositions[circle.id] = CGFloat.random(in: leftBound...rightBound)
                    }
                }
            }
            
            // 请求位置和天气信息
            Task {
                isLoadingWeather = true
                weatherInfo = await weatherService.requestLocationAndWeather()
                isLoadingWeather = false
            }
        }
        .onDisappear {
            // 视图消失时重置状态
            gardenStartTime = nil
            gardenFlowerHeights = [:]
            gardenFlowerPositions = [:]
        }
    }
    
    // MARK: - 花朵位置和大小计算
    
    private func getOrCreateFlowerHeight(for id: UUID, screenHeight: CGFloat) -> CGFloat {
        // 直接返回已存储的高度，不再动态生成
        return gardenFlowerHeights[id] ?? (screenHeight * 0.5)
    }
    
    private func calculateGardenFlowerX(circleId: UUID, screenWidth: CGFloat) -> CGFloat {
        // 直接返回已存储的位置，不再动态生成
        return gardenFlowerPositions[circleId] ?? (screenWidth / 2)
    }
    
    private func calculateGardenFlowerSize(photoCount: Int) -> CGFloat {
        // 需要知道最大照片数来计算归一化比例
        let maxPhotoCount = colorCircles.map { $0.photoCount }.max() ?? 1
        let normalizedCount = CGFloat(photoCount) / CGFloat(maxPhotoCount)
        let radius = GardenFlowerLayout.minFlowerRadius + 
                    (GardenFlowerLayout.maxFlowerRadius - GardenFlowerLayout.minFlowerRadius) * sqrt(normalizedCount)
        return radius * 2  // 返回直径
    }
    
    // MARK: - 花朵绘制
    
    private func drawGardenFlower(
        context: inout GraphicsContext,
        size: CGSize,
        time t: TimeInterval,
        groundY: CGFloat,
        circle: GardenColorCircle,
        index: Int,
        total: Int
    ) {
        let x = calculateGardenFlowerX(circleId: circle.id, screenWidth: size.width)
        
        // 使用预先生成的随机高度
        let maxHeight = getOrCreateFlowerHeight(for: circle.id, screenHeight: size.height)
        
        // 生长进度
        let growT = max(0, min(1, t / GardenFlowerLayout.growDuration))
        let growth = easeOutCubic(CGFloat(growT))
        let currentHeight = maxHeight * growth
        
        // 摇曳
        let phase = Double(index) * 0.5
        let sway = sin(t * GardenFlowerLayout.swaySpeed + phase) * GardenFlowerLayout.swayAmplitude * growth
        
        let base = CGPoint(x: x, y: groundY)
        let stemTop = CGPoint(x: x + sway, y: groundY - currentHeight * GardenFlowerLayout.stemHeightRatio)
        let flowerTop = CGPoint(x: x + sway, y: groundY - currentHeight)
        
        // 计算花朵大小
        let flowerSize = calculateGardenFlowerSize(photoCount: circle.photoCount)
        
        // 绘制茎
        if currentHeight > 1 {
            let c1 = CGPoint(x: x + sway * 0.15, y: groundY - currentHeight * 0.35)
            let c2 = CGPoint(x: x + sway * 0.65, y: groundY - currentHeight * 0.70)
            
            var path = Path()
            path.move(to: base)
            path.addCurve(to: stemTop, control1: c1, control2: c2)
            
            context.stroke(path, with: .color(circle.color.opacity(0.9)), lineWidth: 2.5)
        }
        
        // 花朵开放进度
        let bloomStart: CGFloat = 0.65
        let bloomT = max(0, min(1, (growth - bloomStart) / (1 - bloomStart)))
        
        if bloomT > 0 {
            drawGardenFlowerPetals(
                context: &context,
                center: flowerTop,
                bloom: CGFloat(bloomT),
                time: t,
                color: circle.color,
                size: flowerSize,
                phase: phase
            )
        }
    }
    
    private func drawGardenFlowerPetals(
        context: inout GraphicsContext,
        center: CGPoint,
        bloom: CGFloat,
        time t: TimeInterval,
        color: Color,
        size: CGFloat,
        phase: Double
    ) {
        let bloomEase = easeOutBack(bloom)
        let rotation = sin(t * GardenFlowerLayout.swaySpeed + phase) * 0.3
        
        let flowerSize = size
        let petalRadius = flowerSize * bloomEase
        let petalLength = flowerSize * 1.4 * bloomEase
        
        for i in 0..<GardenFlowerLayout.petalCount {
            let angle = Double(i) / Double(GardenFlowerLayout.petalCount) * .pi * 2 + rotation
            let dir = CGVector(dx: cos(angle), dy: sin(angle))
            let petalCenter = CGPoint(
                x: center.x + dir.dx * petalRadius,
                y: center.y + dir.dy * petalRadius
            )
            
            var petalContext = context
            petalContext.translateBy(x: petalCenter.x, y: petalCenter.y)
            petalContext.rotate(by: .radians(angle))
            
            let rect = CGRect(
                x: -petalLength * 0.5,
                y: -flowerSize * 0.45,
                width: petalLength,
                height: flowerSize * 0.9
            )
            
            let petal = Path(ellipseIn: rect)
            petalContext.fill(petal, with: .color(color.opacity(0.95)))
            petalContext.stroke(petal, with: .color(color.opacity(0.4)), lineWidth: 1)
        }
    }
}

// MARK: - 天气信息显示视图

struct WeatherInfoView: View {
    let weatherInfo: LocationWeatherInfo
    
    var body: some View {
        HStack(spacing: 6) {
            Text(weatherInfo.locationName)
                .font(.system(size: 14, weight: .medium))
            
            Text("·")
                .font(.system(size: 14))
            
            Text(weatherInfo.condition)
                .font(.system(size: 14))
            
            Text("·")
                .font(.system(size: 14))
            
            Text(String(format: "%.0f°C", weatherInfo.temperature))
                .font(.system(size: 14, weight: .medium))
            
            Text(String(format: "(%.0f°C - %.0f°C)", weatherInfo.lowTemperature, weatherInfo.highTemperature))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 缓动函数（GardenFlowerView 专用）

extension GardenFlowerView {
    
    fileprivate func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }
    
    fileprivate func easeOutBack(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.70158
        let c3 = c1 + 1
        let t1 = t - 1
        return 1 + c3 * t1 * t1 * t1 + c1 * t1 * t1
    }
}

