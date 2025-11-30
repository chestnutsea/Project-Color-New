import SwiftUI
import CoreData
import Combine
import Photos

// MARK: - 布局常量

private enum LayoutConstants {
    // 聚类参数
    static let minK: Int = 3   // 最小簇数
    static let maxK: Int = 18  // 最大簇数
    
    // 二次加权参数
    static let chromaThreshold: Float = 10      // 饱和度阈值 Tc
    static let darkLThreshold: Float = 10       // 深暗惩罚阈值 TL_dark
    static let brightLThreshold: Float = 65     // 高亮奖励阈值 TL_bright
    static let lowChromaFactor: Float = 0.3     // 低饱和度权重因子
    static let darkFactor: Float = 0.5          // 深暗惩罚因子
    static let brightFactor: Float = 1.5        // 高亮奖励因子
    static let smallAreaThreshold: Float = 0.05 // 小面积阈值
    static let smallAreaFactor: Float = 0.5     // 小面积惩罚因子
    
    // 矩形详情视图
    static let detailViewPadding: CGFloat = 100  // 屏幕宽度 - 40
    static let detailViewTopMargin: CGFloat = 300  // 屏幕高度 - 150
    static let cornerRadius: CGFloat = 10  // 圆角半径
    
    // 照片网格
    static let photosPerRow: Int = 3
    static let photoSpacing: CGFloat = 5  // 照片之间的间距
    static let photoCornerRadius: CGFloat = 5  // 照片圆角
    static let gridPadding: CGFloat = 10  // 照片网格与矩形边缘的间距
    
    // 矩形毛玻璃效果
    static let materialOpacity: Double = 0  // 毛玻璃透明度
    // 使用 .ultraThinMaterial, .thinMaterial, .regularMaterial, .thickMaterial, .ultraThickMaterial
}

// MARK: - Perlin Noise 运动参数

private enum PerlinMotion {
    static let noiseScale: CGFloat = 0.003     // 噪声缩放因子（值越小运动越平滑）
    static let timeScale: CGFloat = 0.008      // 时间缩放因子（值越小变化越慢）
    static let maxSpeed: CGFloat = 0.6         // 最大速度
    static let boundarySoftness: CGFloat = 0.3 // 边界软回弹力度
    static let boundaryPadding: CGFloat = 16   // 边界安全距离
}

// MARK: - Perlin Noise 生成器

private struct PerlinNoise {
    // 预计算的随机梯度表（256 个）
    private static let permutation: [Int] = {
        var p = Array(0..<256)
        // 使用固定种子打乱，确保每次运行一致
        var rng = SeededRandomNumberGenerator(seed: 42)
        p.shuffle(using: &rng)
        return p + p // 复制一份避免越界
    }()
    
    // 梯度向量（2D）- 使用元组代替 SIMD2
    private static let gradients: [(Double, Double)] = {
        let sqrt2inv = 1.0 / sqrt(2.0)
        return [
            (1, 0), (-1, 0), (0, 1), (0, -1),
            (sqrt2inv, sqrt2inv), (-sqrt2inv, sqrt2inv),
            (sqrt2inv, -sqrt2inv), (-sqrt2inv, -sqrt2inv)
        ]
    }()
    
    // 获取 2D Perlin Noise 值（范围 -1 到 1）
    static func noise2D(x: CGFloat, y: CGFloat) -> CGFloat {
        let xd = Double(x)
        let yd = Double(y)
        
        // 获取整数部分
        let xi = Int(floor(xd)) & 255
        let yi = Int(floor(yd)) & 255
        
        // 获取小数部分
        let xf = xd - floor(xd)
        let yf = yd - floor(yd)
        
        // 平滑插值曲线（6t^5 - 15t^4 + 10t^3）
        let u = fade(xf)
        let v = fade(yf)
        
        // 获取四个角的梯度索引
        let aa = permutation[permutation[xi] + yi] & 7
        let ab = permutation[permutation[xi] + yi + 1] & 7
        let ba = permutation[permutation[xi + 1] + yi] & 7
        let bb = permutation[permutation[xi + 1] + yi + 1] & 7
        
        // 计算四个角的点积
        let gradAA = gradients[aa]
        let gradAB = gradients[ab]
        let gradBA = gradients[ba]
        let gradBB = gradients[bb]
        
        let dotAA = gradAA.0 * xf + gradAA.1 * yf
        let dotAB = gradAB.0 * xf + gradAB.1 * (yf - 1)
        let dotBA = gradBA.0 * (xf - 1) + gradBA.1 * yf
        let dotBB = gradBB.0 * (xf - 1) + gradBB.1 * (yf - 1)
        
        // 双线性插值
        let x1 = lerp(dotAA, dotBA, u)
        let x2 = lerp(dotAB, dotBB, u)
        
        return CGFloat(lerp(x1, x2, v))
    }
    
    // 平滑曲线
    private static func fade(_ t: Double) -> Double {
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    // 线性插值
    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + t * (b - a)
    }
}

// 固定种子随机数生成器
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - 主视图（EmergeView）

struct EmergeView: View {
    
    @StateObject private var viewModel = ViewModel()
    @State private var screenSize: CGSize = .zero
    @State private var isAnimating = false
    @State private var selectedCircleID: UUID? = nil  // 选中的圆形 ID
    @State private var fullScreenPhotoIndex: Int? = nil  // 全屏查看的照片索引
    @State private var fullScreenPhotos: [ViewModel.PhotoInfo] = []  // 全屏查看的照片列表
    
    // ✅ 锚点状态：记录点击时圆形的位置和半径
    @State private var anchorPosition: CGPoint = .zero
    @State private var anchorRadius: CGFloat = 0
    @State private var anchorColor: Color = .clear
    @State private var anchorPhotos: [ViewModel.PhotoInfo] = []
    
    // ✅ 防止重复加载
    @State private var hasLoadedOnce = false
    @State private var lastKnownPhotoCount: Int = 0  // 上次已知的照片数量
    
    // ✅ 计算属性：根据 ID 获取实时的 circle 数据（用于颜色等信息，不用于位置）
    private var selectedCircle: ViewModel.ColorCircle? {
        guard let id = selectedCircleID else { return nil }
        return viewModel.colorCircles.first { $0.id == id }
    }
    
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                
                // ✅ 锁屏级空间背景（白黑自适应）
                appleSpaceBackground
                
                if viewModel.isLoading {
                    loadingView
                }
                // ✅ 恢复 10 张照片限制
                else if viewModel.analyzedPhotoCount < 10 {
                    insufficientPhotosView
                }
                // ✅ 展示真实聚类结果
                else if !viewModel.colorCircles.isEmpty {
                    ZStack {
                        ForEach(viewModel.colorCircles) { circle in
                            // 发光效果层（不响应点击）
                            glowingCircleGlow(circle: circle)
                                .position(circle.position)
                                .allowsHitTesting(false)
                        }
                        
                        ForEach(viewModel.colorCircles) { circle in
                            // 核心圆形（响应点击）
                            Circle()
                                .fill(circle.color)
                                .frame(width: circle.radius * 2, height: circle.radius * 2)
                                .opacity(0.92)
                                .position(circle.position)
                                .onTapGesture {
                                    // 记录点击时的锚点信息
                                    anchorPosition = circle.position
                                    anchorRadius = circle.radius
                                    anchorColor = circle.color
                                    anchorPhotos = circle.photos
                                    
                                    // 直接显示详情视图，无动画，圆继续移动
                                    selectedCircleID = circle.id
                                }
                        }
                    }
                }
                
                // ✅ 详情视图（选中时显示，无动画）
                if selectedCircleID != nil {
                    detailView()
                }
                
                if let error = viewModel.errorMessage {
                    errorView(message: error)
                }
            }
            // ✅ 全屏查看：使用 fullScreenCover 完全覆盖（包括 TabBar）
            .fullScreenCover(isPresented: Binding(
                get: { fullScreenPhotoIndex != nil },
                set: { if !$0 { fullScreenPhotoIndex = nil } }
            )) {
                if let photoIndex = fullScreenPhotoIndex {
                    FullScreenPhotoView(
                        photos: fullScreenPhotos,
                        currentIndex: photoIndex,
                        onDismiss: {
                            fullScreenPhotoIndex = nil
                        }
                    )
                }
            }
            .onAppear {
                screenSize = geometry.size
                
                // ✅ 检查照片数量是否变化（增加或删除了照片）
                Task {
                    let currentPhotoCount = await viewModel.fetchCurrentPhotoCount()
                    
                    await MainActor.run {
                        // 如果照片数量变化，需要重新聚类
                        let photoCountChanged = hasLoadedOnce && currentPhotoCount != lastKnownPhotoCount
                        
                        if photoCountChanged {
                            print("📊 显影页：检测到照片数量变化 \(lastKnownPhotoCount) → \(currentPhotoCount)，重新聚类")
                            hasLoadedOnce = false  // 重置标志，触发重新聚类
                        }
                        
                        // 只在首次加载或照片数量变化时执行聚类
                        guard !hasLoadedOnce else {
                            // 恢复动画（如果已有数据）
                            if !viewModel.colorCircles.isEmpty {
                                isAnimating = true
                            }
                            return
                        }
                        
                        hasLoadedOnce = true
                        lastKnownPhotoCount = currentPhotoCount
                        isAnimating = false
                        viewModel.reset()
                        
                        Task {
                            await viewModel.performClustering(screenSize: geometry.size)
                        }
                    }
                }
            }
            .onDisappear {
                // ✅ 视图消失时停止动画，减少资源消耗
                isAnimating = false
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                if !isLoading && !viewModel.colorCircles.isEmpty {
                    isAnimating = true
                }
            }
            .onReceive(timer) { _ in
                guard isAnimating else { return }
                viewModel.updatePerlinNoiseMotion(screenSize: screenSize)
            }
        }
    }
}

// MARK: - ✅ 内嵌 ViewModel（你原本就在这个文件里的那种结构）

@MainActor
final class ViewModel: ObservableObject {
    
    struct ColorCircle: Identifiable {
        let id = UUID()
        let color: Color
        let rgb: SIMD3<Float>
        let lab: SIMD3<Float>  // LAB 质心（用于计算照片距离）
        let photoCount: Int
        var position: CGPoint
        var radius: CGFloat
        var velocity: CGPoint
        var photos: [PhotoInfo] = []  // 预计算的归属照片
        
        // Perlin Noise 运动参数
        var noiseOffsetX: CGFloat = 0  // X 方向噪声偏移
        var noiseOffsetY: CGFloat = 0  // Y 方向噪声偏移
        var time: CGFloat = 0          // 时间累积
    }
    
    struct PhotoInfo: Identifiable {
        let assetIdentifier: String
        let distance: Float  // 到簇质心的 ΔE 距离
        
        var id: String { assetIdentifier }
    }
    
    // ✅ 带来源的颜色信息（用于追溯照片归属）
    struct ColorWithSource {
        let rgb: SIMD3<Float>
        let weight: Float
        let assetIdentifier: String
    }
    
    @Published var isLoading = true
    @Published var colorCircles: [ColorCircle] = []
    @Published var analyzedPhotoCount: Int = 0
    @Published var errorMessage: String? = nil
    
    private let coreDataManager = CoreDataManager.shared
    private let kmeans = SimpleKMeans()
    private let converter = ColorSpaceConverter()
    
    func reset() {
        isLoading = true
        colorCircles = []
        errorMessage = nil
        analyzedPhotoCount = 0
    }
    
    /// 获取当前数据库中的照片数量（在后台线程执行）
    func fetchCurrentPhotoCount() async -> Int {
        return await Task.detached(priority: .userInitiated) { [coreDataManager] in
            let context = coreDataManager.newBackgroundContext()
            var count = 0
            
            context.performAndWait {
                let request = PhotoAnalysisEntity.fetchRequest()
                do {
                    count = try context.count(for: request)
                } catch {
                    print("❌ 获取照片数量失败: \(error)")
                }
            }
            
            return count
        }.value
    }
    
    // ✅ 聚类逻辑：使用 assignments 直接追溯照片归属
    func performClustering(screenSize: CGSize) async {
        isLoading = true
        errorMessage = nil
        colorCircles = []
        
        // 在后台线程执行所有计算密集型操作
        let result = await Task.detached(priority: .userInitiated) { [coreDataManager, kmeans, converter] in
            return ViewModel.performClusteringBackground(
                coreDataManager: coreDataManager,
                kmeans: kmeans,
                converter: converter,
                screenSize: screenSize
            )
        }.value
        
        // 更新 UI（在主线程）
        analyzedPhotoCount = result.photoCount
        
        if let error = result.error {
            errorMessage = error
            isLoading = false
            return
        }
        
        colorCircles = result.circles
            isLoading = false
    }
    
    // 聚类结果结构
    struct ClusteringBackgroundResult {
        let circles: [ColorCircle]
        let photoCount: Int
        let error: String?
    }
    
    // MARK: - 欧几里得距离（与 SimpleKMeans 保持一致）
    /// 在 LAB 空间使用欧几里得距离，将颜色视为 3D 向量 (L, a, b)
    nonisolated private static func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    // ✅ 后台线程执行聚类计算（内存优化版）
    nonisolated private static func performClusteringBackground(
        coreDataManager: CoreDataManager,
        kmeans: SimpleKMeans,
        converter: ColorSpaceConverter,
        screenSize: CGSize
    ) -> ClusteringBackgroundResult {
        // 获取颜色数据和预存储的视觉代表色
        let (colorSources, photoCount, storedVisualColors) = fetchColorsWithSourceBackground(coreDataManager: coreDataManager)
        
        guard photoCount >= 10 else {
            return ClusteringBackgroundResult(circles: [], photoCount: photoCount, error: nil)
        }
        
        guard !colorSources.isEmpty else {
            return ClusteringBackgroundResult(circles: [], photoCount: photoCount, error: "没有找到颜色数据")
        }
        
        // ✅ 优化：一次性转换 LAB 并存储，避免重复转换
        struct ColorWithLAB {
            let rgb: SIMD3<Float>
            let lab: SIMD3<Float>
            let weight: Float
            let assetIdentifier: String
        }
        
        // 使用 autoreleasepool 管理内存
        var colorsWithLAB: [ColorWithLAB] = []
        colorsWithLAB.reserveCapacity(colorSources.count)
        
        for colorSource in colorSources {
            autoreleasepool {
                let lab = converter.rgbToLab(colorSource.rgb)
                colorsWithLAB.append(ColorWithLAB(
                    rgb: colorSource.rgb,
                    lab: lab,
                    weight: colorSource.weight,
                    assetIdentifier: colorSource.assetIdentifier
                ))
            }
        }
        
        // 提取 LAB 数组和权重数组用于聚类
        let labColors = colorsWithLAB.map { $0.lab }
        let weights: [Float] = colorsWithLAB.map { color in
            let L = color.lab.x
            let chroma = sqrt(color.lab.y * color.lab.y + color.lab.z * color.lab.z)
            
            let chromaFactor: Float = chroma < LayoutConstants.chromaThreshold 
                ? LayoutConstants.lowChromaFactor : 1.0
            let darkFactor: Float = L < LayoutConstants.darkLThreshold 
                ? LayoutConstants.darkFactor : 1.0
            let brightFactor: Float = L > LayoutConstants.brightLThreshold 
                ? LayoutConstants.brightFactor : 1.0
            
            return color.weight * chromaFactor * darkFactor * brightFactor
        }
        
        let k = min(max(LayoutConstants.minK, colorsWithLAB.count / 50), LayoutConstants.maxK)
        
        guard let clusterResult = kmeans.cluster(
            points: labColors,
            k: k,
            maxIterations: 50,
            colorSpace: .lab,
            weights: weights
        ) else {
            return ClusteringBackgroundResult(circles: [], photoCount: photoCount, error: "聚类失败")
        }
        
        // ✅ 使用存储的视觉代表色分配照片
        // 如果没有存储的视觉代表色，则回退到旧逻辑（从 dominantColors 计算）
        var photoVisualColor: [String: SIMD3<Float>] = [:]
        photoVisualColor.reserveCapacity(photoCount)
        
        // 收集所有照片的 assetId
        var allAssetIds = Set<String>()
        for color in colorsWithLAB {
            allAssetIds.insert(color.assetIdentifier)
        }
        
        // 构建照片颜色字典（用于回退计算）
        var photoColors: [String: [(lab: SIMD3<Float>, weight: Float)]] = [:]
        for color in colorsWithLAB {
            let assetId = color.assetIdentifier
            if photoColors[assetId] == nil {
                photoColors[assetId] = []
            }
            photoColors[assetId]?.append((lab: color.lab, weight: color.weight))
        }
        
        for assetId in allAssetIds {
            // ✅ 优先使用存储的视觉代表色
            if let storedRGB = storedVisualColors[assetId] {
                // 将存储的 RGB 转换为 LAB
                let storedLAB = converter.rgbToLab(storedRGB)
                photoVisualColor[assetId] = storedLAB
            } else {
                // 回退：从 dominantColors 计算视觉代表色
                guard let colors = photoColors[assetId] else { continue }
                
                var bestLab: SIMD3<Float>? = nil
                var bestScore: Float = -Float.infinity
                
                for color in colors {
                    let L = color.lab.x
                    let chroma = sqrt(color.lab.y * color.lab.y + color.lab.z * color.lab.z)
                    let weight = color.weight
                    
                    let chromaFactor: Float = chroma < LayoutConstants.chromaThreshold 
                        ? LayoutConstants.lowChromaFactor : 1.0
                    let darkFactor: Float = L < LayoutConstants.darkLThreshold 
                        ? LayoutConstants.darkFactor : 1.0
                    let brightFactor: Float = L > LayoutConstants.brightLThreshold 
                        ? LayoutConstants.brightFactor : 1.0
                    let areaFactor: Float = weight < LayoutConstants.smallAreaThreshold 
                        ? LayoutConstants.smallAreaFactor : 1.0
                    
                    let visualScore = weight * chromaFactor * darkFactor * brightFactor * areaFactor
                    if visualScore > bestScore {
                        bestScore = visualScore
                        bestLab = color.lab
                    }
                }
                
                if let lab = bestLab {
                    photoVisualColor[assetId] = lab
                }
            }
        }
        
        print("📊 显影页视觉代表色统计: 存储 \(storedVisualColors.count) / 计算 \(photoVisualColor.count - storedVisualColors.count)")
        
        // 将照片分配到最近的簇
        var clusterToPhotos: [Int: [(assetId: String, distance: Float)]] = [:]
        
        for (assetId, visualColorLAB) in photoVisualColor {
            var minDistance: Float = .infinity
            var nearestClusterIndex = 0
            
            for (clusterIndex, centroid) in clusterResult.centroids.enumerated() {
                let distance = euclideanDistance(visualColorLAB, centroid)
                if distance < minDistance {
                    minDistance = distance
                    nearestClusterIndex = clusterIndex
                }
            }
            
            if clusterToPhotos[nearestClusterIndex] == nil {
                clusterToPhotos[nearestClusterIndex] = []
            }
            clusterToPhotos[nearestClusterIndex]?.append((assetId: assetId, distance: minDistance))
        }
        
        let maxPhotoCount = clusterToPhotos.values.map { $0.count }.max() ?? 1
        
        var circles: [ColorCircle] = []
        circles.reserveCapacity(clusterResult.centroids.count)
        
        for (clusterIndex, centroidLAB) in clusterResult.centroids.enumerated() {
            guard let photos = clusterToPhotos[clusterIndex], !photos.isEmpty else {
                continue
            }
            
            let centroidRGB = converter.labToRgb(centroidLAB)
            let color = Color(
                red: Double(centroidRGB.x),
                green: Double(centroidRGB.y),
                blue: Double(centroidRGB.z)
            )
            
            let normalizedCount = CGFloat(photos.count) / CGFloat(maxPhotoCount)
            let radius = 10 + (40 - 10) * sqrt(normalizedCount)
            
            let padding = radius + 20
            let x = CGFloat.random(in: padding...(screenSize.width - padding))
            let y = CGFloat.random(in: padding...(screenSize.height - padding))
            
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 0.4...0.7)
            
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed
            )
            
            let clusterPhotos = photos
                .map { PhotoInfo(assetIdentifier: $0.assetId, distance: $0.distance) }
                .sorted { $0.distance < $1.distance }
            
            // 为每个圆生成独立的噪声偏移（确保运动不同步）
            let noiseOffsetX = CGFloat.random(in: 0...1000)
            let noiseOffsetY = CGFloat.random(in: 0...1000)
            let initialTime = CGFloat.random(in: 0...100)
            
            circles.append(ColorCircle(
                color: color,
                rgb: centroidRGB,
                lab: centroidLAB,
                photoCount: photos.count,
                position: CGPoint(x: x, y: y),
                radius: radius,
                velocity: velocity,
                photos: clusterPhotos,
                noiseOffsetX: noiseOffsetX,
                noiseOffsetY: noiseOffsetY,
                time: initialTime
            ))
        }
        
        return ClusteringBackgroundResult(circles: circles, photoCount: photoCount, error: nil)
    }
    
    // ✅ 获取带来源的颜色信息（后台线程版本，内存优化）
    nonisolated private static func fetchColorsWithSourceBackground(coreDataManager: CoreDataManager) -> ([ColorWithSource], Int, [String: SIMD3<Float>]) {
        let context = coreDataManager.newBackgroundContext()
        var colorSources: [ColorWithSource] = []
        var photoCount = 0
        var photoVisualColors: [String: SIMD3<Float>] = [:]  // 存储每张照片的视觉代表色
        
        context.performAndWait {
            let request = PhotoAnalysisEntity.fetchRequest()
            // 获取需要的属性
            request.propertiesToFetch = [
                "assetLocalIdentifier", 
                "dominantColors",
                "visualRepresentativeColorR",
                "visualRepresentativeColorG",
                "visualRepresentativeColorB"
            ]
        
            do {
                let results = try context.fetch(request)
                photoCount = results.count
            
                // 预分配容量
                colorSources.reserveCapacity(photoCount * 5)
                photoVisualColors.reserveCapacity(photoCount)
                
                // 复用 JSONDecoder
                let decoder = JSONDecoder()
            
                for entity in results {
                    autoreleasepool {
                        guard let assetId = entity.assetLocalIdentifier,
                              let data = entity.dominantColors,
                              let colors = try? decoder.decode([DominantColor].self, from: data) else {
                            return
                        }
                        
                        // 读取存储的视觉代表色（如果有）
                        let r = entity.visualRepresentativeColorR
                        let g = entity.visualRepresentativeColorG
                        let b = entity.visualRepresentativeColorB
                        
                        // 如果 RGB 都不为 0，说明有存储的视觉代表色
                        if r != 0 || g != 0 || b != 0 {
                            photoVisualColors[assetId] = SIMD3<Float>(r, g, b)
                        }
                
                        // 每个颜色都记录来源照片（用于聚类）
                        for color in colors {
                            colorSources.append(ColorWithSource(
                                rgb: color.rgb,
                                weight: color.weight,
                                assetIdentifier: assetId
                            ))
                        }
                    }
                }
            } catch {
                print("❌ 获取颜色数据失败: \(error)")
            }
        }
        
        return (colorSources, photoCount, photoVisualColors)
    }
    
    // ✅ Perlin Noise 驱动的运动逻辑
    func updatePerlinNoiseMotion(screenSize: CGSize) {
        for i in 0..<colorCircles.count {
            var c = colorCircles[i]
            
            // 更新时间
            c.time += PerlinMotion.timeScale
            
            // 使用 Perlin Noise 计算速度方向
            // 每个圆有独立的噪声偏移，确保运动不同步
            let noiseX = PerlinNoise.noise2D(
                x: c.position.x * PerlinMotion.noiseScale + c.noiseOffsetX,
                y: c.time
            )
            let noiseY = PerlinNoise.noise2D(
                x: c.position.y * PerlinMotion.noiseScale + c.noiseOffsetY,
                y: c.time + 100  // 偏移避免 X/Y 相关
            )
            
            // 将噪声值映射到速度（-1~1 → -maxSpeed~maxSpeed）
            c.velocity.x = noiseX * PerlinMotion.maxSpeed
            c.velocity.y = noiseY * PerlinMotion.maxSpeed
            
            // 更新位置
            c.position.x += c.velocity.x
            c.position.y += c.velocity.y
            
            // 边界处理：软回弹
            let pad = c.radius + PerlinMotion.boundaryPadding
            
            if c.position.x < pad {
                c.position.x = pad
                c.velocity.x = abs(c.velocity.x) * PerlinMotion.boundarySoftness
            }
            if c.position.x > screenSize.width - pad {
                c.position.x = screenSize.width - pad
                c.velocity.x = -abs(c.velocity.x) * PerlinMotion.boundarySoftness
            }
            if c.position.y < pad {
                c.position.y = pad
                c.velocity.y = abs(c.velocity.y) * PerlinMotion.boundarySoftness
            }
            if c.position.y > screenSize.height - pad {
                c.position.y = screenSize.height - pad
                c.velocity.y = -abs(c.velocity.y) * PerlinMotion.boundarySoftness
            }
            
            colorCircles[i] = c
        }
    }
    
}

// MARK: - ✅ 发光能量球（无呼吸缩放）

extension EmergeView {
    
    // 发光效果（不包含核心圆形）
    private func glowingCircleGlow(circle: ViewModel.ColorCircle) -> some View {
        let r = circle.radius
        
        return ZStack {
            // 外层发光效果
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            circle.color.opacity(0.35),
                            circle.color.opacity(0.15),
                            .clear
                        ]),
                        center: .center,
                        startRadius: r * 0.3,
                        endRadius: r * 2.2
                    )
                )
                .frame(width: r * 4.4, height: r * 4.4)
                .blendMode(.screen)
            
            // 中层模糊
            Circle()
                .fill(circle.color)
                .frame(width: r * 2.4, height: r * 2.4)
                .blur(radius: r * 0.25)
                .opacity(0.35)
        }
    }
}

// MARK: - ✅ 详情视图

extension EmergeView {
    
    @ViewBuilder
    private func detailView() -> some View {
        ZStack {
            // 半透明背景（点击关闭）
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // 直接关闭，无动画，圆继续移动
                    selectedCircleID = nil
                }
            
            // 详情矩形（无动画）
            detailContentView()
        }
    }
    
    @ViewBuilder
    private func detailContentView() -> some View {
        VStack(spacing: 0) {
            // 照片网格
            photoGridView()
        }
        .frame(
            width: screenSize.width - LayoutConstants.detailViewPadding,
            height: screenSize.height - LayoutConstants.detailViewTopMargin
        )
        .background(
            ZStack {
                // 毛玻璃效果（底层）
                RoundedRectangle(cornerRadius: LayoutConstants.cornerRadius)
                    .fill(.ultraThinMaterial)
                
                // 颜色叠加（使用锚点颜色）
                RoundedRectangle(cornerRadius: LayoutConstants.cornerRadius)
                    .fill(anchorColor.opacity(0.6))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutConstants.cornerRadius)
                .stroke(anchorColor.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: anchorColor.opacity(0.3), radius: 20, x: 0, y: 10)
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 下滑关闭，无动画，圆继续移动
                    if value.translation.height > 100 {
                        selectedCircleID = nil
                    }
                }
        )
    }
    
    private func photoGridView() -> some View {
        // 使用锚点保存的照片列表
        let photos = anchorPhotos
        
        // 计算每张照片的尺寸（正方形）
        let containerWidth = screenSize.width - LayoutConstants.detailViewPadding
        let horizontalPadding = LayoutConstants.gridPadding * 2  // 左右边距
        let availableWidth = containerWidth - horizontalPadding
        let totalSpacing = LayoutConstants.photoSpacing * CGFloat(LayoutConstants.photosPerRow - 1)
        let photoSize = floor((availableWidth - totalSpacing) / CGFloat(LayoutConstants.photosPerRow))
        
        // ✅ 使用 .fixed 确保每个格子固定尺寸，避免空位
        let columns = Array(repeating: GridItem(
            .fixed(photoSize),
            spacing: LayoutConstants.photoSpacing
        ), count: LayoutConstants.photosPerRow)
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: LayoutConstants.photoSpacing) {
                ForEach(photos) { photoInfo in
                    PhotoThumbnailView(assetIdentifier: photoInfo.assetIdentifier, size: photoSize)
                        .frame(width: photoSize, height: photoSize)
                        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.photoCornerRadius))
                        .onTapGesture {
                            fullScreenPhotos = photos
                            if let index = photos.firstIndex(where: { $0.id == photoInfo.id }) {
                                fullScreenPhotoIndex = index
                            }
                        }
                }
            }
            .padding(.horizontal, LayoutConstants.gridPadding)
            .padding(.vertical, LayoutConstants.gridPadding)
        }
    }
}

// MARK: - ✅ 照片缩略图

struct PhotoThumbnailView: View {
    let assetIdentifier: String
    let size: CGFloat
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(ProgressView().scaleEffect(0.8))
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        // 使用 2x 尺寸以适配 Retina 屏幕
        let targetSize = CGSize(width: size * 2, height: size * 2)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
        }
    }
}

// MARK: - ✅ 全屏查看（模仿 iOS 原生照片 App 交互）

struct FullScreenPhotoView: View {
    let photos: [ViewModel.PhotoInfo]
    @State private var currentIndex: Int
    @State private var dragOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0
    @State private var imageScale: CGFloat = 1.0
    @State private var isDragging: Bool = false
    
    let onDismiss: () -> Void
    
    init(photos: [ViewModel.PhotoInfo], currentIndex: Int, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self._currentIndex = State(initialValue: currentIndex)
        self.onDismiss = onDismiss
    }
    
    // 计算拖动进度 (0~1)
    private var dragProgress: CGFloat {
        min(max(dragOffset.height, 0) / 300, 1.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景：随拖动渐变透明
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                
                // 照片容器
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.assetIdentifier) { index, photo in
                        SinglePhotoView(assetIdentifier: photo.assetIdentifier)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scaleEffect(imageScale)
                .offset(dragOffset)
                
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let translation = value.translation
                        
                        // 判断是否是向下拖动（首次移动方向决定）
                        if !isDragging {
                            // 只有垂直分量大于水平分量才开始拖动
                            if abs(translation.height) > abs(translation.width) && translation.height > 0 {
                                isDragging = true
                            }
                        }
                        
                        if isDragging {
                            // 位置跟随手指
                            dragOffset = translation
                            
                            // 背景透明度随拖动距离变化（最低到 0）
                            let progress = dragProgress
                            backgroundOpacity = 1.0 - progress
                            
                            // 图片缩小效果（最小到 0.7）
                            imageScale = 1.0 - progress * 0.3
                        }
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false
                        
                        let translation = value.translation
                        let velocity = value.predictedEndTranslation.height - translation.height
                        
                        // 如果拖动距离或速度足够，则关闭
                        if translation.height > 120 || velocity > 300 {
                            // 继续动画到屏幕外
                            let targetY = geometry.size.height
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragOffset = CGSize(width: translation.width * 1.5, height: targetY)
                                backgroundOpacity = 0
                                imageScale = 0.5
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDismiss()
                            }
                        } else {
                            // 回弹
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = .zero
                                backgroundOpacity = 1.0
                                imageScale = 1.0
                            }
                        }
                    }
            )
            
            // 关闭按钮（放在手势层之上）
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismissWithAnimation() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9), .black.opacity(0.3))
                            .padding(20)
                    }
                }
                Spacer()
            }
            .opacity(backgroundOpacity)
        }
        .statusBarHidden(true)
    }
    
    private func dismissWithAnimation() {
        // 直接渐变透明关闭，大小位置不变
        withAnimation(.easeOut(duration: 0.25)) {
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - ✅ 单张照片视图（简化版，避免手势冲突）

struct SinglePhotoView: View {
    let assetIdentifier: String
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .gesture(
                            // 捏合手势：放大缩小
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    // 如果缩放小于1.1，自动回到1.0
                                    if scale < 1.1 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            scale = 1.0
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            // 双击手势：快速放大/缩小
                            TapGesture(count: 2)
                                .onEnded {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        scale = scale > 1.0 ? 1.0 : 2.0
                                        lastScale = 1.0
                                    }
                                }
                        )
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = fetchResult.firstObject else { return }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            let screenScale = UIScreen.main.scale
            let screenSize = UIScreen.main.bounds.size
            let targetSize = CGSize(
                width: screenSize.width * screenScale,
                height: screenSize.height * screenScale
            )
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}


// MARK: - ✅ UI 提示

extension EmergeView {
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("正在分析色彩...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var insufficientPhotosView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("扫描 10 张照片开启色彩显影")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            if viewModel.analyzedPhotoCount > 0 {
                Text("当前已扫描 \(viewModel.analyzedPhotoCount) 张")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding()
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.secondary.opacity(0.6))
        }
    }
}

// MARK: - ✅ 空间背景

extension EmergeView {
    
    private var appleSpaceBackground: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            LinearGradient(
                colors: [Color.primary.opacity(0.05), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            LinearGradient(
                colors: [.clear, Color.primary.opacity(0.06)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

#if DEBUG
struct EmergeView_Previews: PreviewProvider {
    static var previews: some View {
        EmergeView()
    }
}
#endif
