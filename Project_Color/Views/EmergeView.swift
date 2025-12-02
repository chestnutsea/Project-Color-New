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
    
    // 影调模式 - 圆角正方形参数
    static let tonalMinSize: CGFloat = 20       // 最小边长
    static let tonalMaxSize: CGFloat = 80       // 最大边长
    static let tonalMaxCornerRatio: CGFloat = 0.5  // 最大圆角比例（对比度=0时）
    // 对比度 0-100 线性对应 radius 0.5-0
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
    @State private var lastKnownDevelopmentMode: BatchProcessSettings.DevelopmentMode = .tone  // 上次已知的显影解析模式
    
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
                // ✅ 影调模式：展示圆角正方形
                else if viewModel.currentMode == .shadow && !viewModel.tonalSquares.isEmpty {
                    ZStack {
                        ForEach(viewModel.tonalSquares) { square in
                            // 发光效果层（不响应点击）
                            glowingSquareGlow(square: square)
                                .position(square.position)
                                .allowsHitTesting(false)
                        }
                        
                        ForEach(viewModel.tonalSquares) { square in
                            // 核心圆角正方形（响应点击）
                            RoundedRectangle(cornerRadius: square.cornerRadius)
                                .fill(square.grayColor)
                                .frame(width: square.size, height: square.size)
                                .opacity(0.92)
                                .position(square.position)
                                .onTapGesture {
                                    // 记录点击时的锚点信息
                                    anchorPosition = square.position
                                    anchorRadius = square.size / 2
                                    anchorColor = square.grayColor
                                    anchorPhotos = square.photos
                                    
                                    // 直接显示详情视图
                                    selectedCircleID = square.id
                                }
                        }
                    }
                }
                // ✅ 色调/综合模式：展示圆形
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
                
                // ✅ 检查照片数量或显影解析模式是否变化
                Task {
                    let currentPhotoCount = await viewModel.fetchCurrentPhotoCount()
                    let currentDevelopmentMode = BatchProcessSettings.developmentMode
                    
                    await MainActor.run {
                        // 如果照片数量变化，需要重新聚类
                        let photoCountChanged = hasLoadedOnce && currentPhotoCount != lastKnownPhotoCount
                        
                        // 如果显影解析模式变化，需要重新聚类
                        let developmentModeChanged = hasLoadedOnce && currentDevelopmentMode != lastKnownDevelopmentMode
                        
                        if photoCountChanged {
                            print("📊 显影页：检测到照片数量变化 \(lastKnownPhotoCount) → \(currentPhotoCount)，重新聚类")
                            hasLoadedOnce = false  // 重置标志，触发重新聚类
                        }
                        
                        if developmentModeChanged {
                            print("📊 显影页：检测到显影解析模式变化 \(lastKnownDevelopmentMode.rawValue) → \(currentDevelopmentMode.rawValue)，重新聚类")
                            hasLoadedOnce = false  // 重置标志，触发重新聚类
                        }
                        
                        // 只在首次加载或设置变化时执行聚类
                        guard !hasLoadedOnce else {
                            // 恢复动画（如果已有数据）
                            if !viewModel.colorCircles.isEmpty {
                                isAnimating = true
                            }
                            return
                        }
                        
                        hasLoadedOnce = true
                        lastKnownPhotoCount = currentPhotoCount
                        lastKnownDevelopmentMode = currentDevelopmentMode
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
                if !isLoading && (!viewModel.colorCircles.isEmpty || !viewModel.tonalSquares.isEmpty) {
                    isAnimating = true
                }
            }
            .onReceive(timer) { _ in
                guard isAnimating else { return }
                if viewModel.currentMode == .shadow {
                    viewModel.updateTonalSquareMotion(screenSize: screenSize)
                } else {
                    viewModel.updatePerlinNoiseMotion(screenSize: screenSize)
                }
            }
        }
    }
}

// MARK: - ✅ 内嵌 ViewModel（你原本就在这个文件里的那种结构）

@MainActor
final class ViewModel: ObservableObject {
    
    // MARK: - 色调/综合模式数据结构
    struct ColorCircle: Identifiable {
        let id: UUID
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
        
        init(id: UUID = UUID(), color: Color, rgb: SIMD3<Float>, lab: SIMD3<Float>, photoCount: Int, position: CGPoint, radius: CGFloat, velocity: CGPoint, photos: [PhotoInfo] = [], noiseOffsetX: CGFloat = 0, noiseOffsetY: CGFloat = 0, time: CGFloat = 0) {
            self.id = id
            self.color = color
            self.rgb = rgb
            self.lab = lab
            self.photoCount = photoCount
            self.position = position
            self.radius = radius
            self.velocity = velocity
            self.photos = photos
            self.noiseOffsetX = noiseOffsetX
            self.noiseOffsetY = noiseOffsetY
            self.time = time
        }
    }
    
    // MARK: - 影调模式数据结构
    struct TonalSquare: Identifiable {
        let id: UUID
        let brightnessMedian: Float  // 明度中位数 (0-100)
        let contrast: Float          // 对比度 (0-100)
        let photoCount: Int
        var position: CGPoint
        var size: CGFloat            // 边长
        var cornerRadius: CGFloat    // 圆角半径
        var velocity: CGPoint
        var photos: [PhotoInfo] = []
        
        // Perlin Noise 运动参数
        var noiseOffsetX: CGFloat = 0
        var noiseOffsetY: CGFloat = 0
        var time: CGFloat = 0
        
        // 计算灰度颜色：L=0 纯黑，L=100 纯白
        var grayColor: Color {
            let gray = Double(brightnessMedian) / 100.0
            return Color(red: gray, green: gray, blue: gray)
        }
        
        init(id: UUID = UUID(), brightnessMedian: Float, contrast: Float, photoCount: Int, position: CGPoint, size: CGFloat, cornerRadius: CGFloat, velocity: CGPoint, photos: [PhotoInfo] = [], noiseOffsetX: CGFloat = 0, noiseOffsetY: CGFloat = 0, time: CGFloat = 0) {
            self.id = id
            self.brightnessMedian = brightnessMedian
            self.contrast = contrast
            self.photoCount = photoCount
            self.position = position
            self.size = size
            self.cornerRadius = cornerRadius
            self.velocity = velocity
            self.photos = photos
            self.noiseOffsetX = noiseOffsetX
            self.noiseOffsetY = noiseOffsetY
            self.time = time
        }
    }
    
    struct PhotoInfo: Identifiable {
        let assetIdentifier: String
        let distance: Float  // 到簇质心的距离
        
        var id: String { assetIdentifier }
    }
    
    // ✅ 带来源的颜色信息（用于追溯照片归属）
    struct ColorWithSource {
        let rgb: SIMD3<Float>
        let weight: Float
        let assetIdentifier: String
    }
    
    // ✅ 影调模式的照片数据
    struct TonalPhotoData {
        let assetIdentifier: String
        let brightnessMedian: Float
        let contrast: Float
    }
    
    @Published var isLoading = true
    @Published var colorCircles: [ColorCircle] = []
    @Published var tonalSquares: [TonalSquare] = []  // 影调模式的圆角正方形
    @Published var analyzedPhotoCount: Int = 0
    @Published var errorMessage: String? = nil
    @Published var currentMode: BatchProcessSettings.DevelopmentMode = .tone
    @Published var isFavoriteOnly: Bool = false  // 是否只显示收藏照片
    
    private let coreDataManager = CoreDataManager.shared
    private let kmeans = SimpleKMeans()
    private let converter = ColorSpaceConverter()
    
    func reset() {
        isLoading = true
        colorCircles = []
        tonalSquares = []
        errorMessage = nil
        analyzedPhotoCount = 0
    }
    
    /// 获取当前数据库中的照片数量（在后台线程执行）
    func fetchCurrentPhotoCount() async -> Int {
        return await coreDataManager.fetchTotalPhotoCount()
    }
    
    /// 获取收藏照片集中的照片数量
    func fetchFavoritePhotoCount() async -> Int {
        let favoriteAlbumIds = AlbumFavoritesStore.shared.load()
        print("📊 收藏相册 ID 列表: \(favoriteAlbumIds)")
        let count = await coreDataManager.fetchFavoritePhotoCount(favoriteAlbumIds: favoriteAlbumIds)
        print("📊 收藏照片数量查询结果: \(count)")
        return count
    }
    
    // MARK: - 主聚类入口（带缓存检测）
    
    /// 执行聚类（优先从缓存加载）
    func performClusteringWithCache(screenSize: CGSize) async {
        isLoading = true
        errorMessage = nil
        colorCircles = []
        tonalSquares = []
        
        let developmentMode = BatchProcessSettings.developmentMode
        let favoriteOnly = BatchProcessSettings.developmentFavoriteOnly
        currentMode = developmentMode
        isFavoriteOnly = favoriteOnly
        
        // 构建缓存 key：mode + favoriteOnly 后缀
        let baseModeString: String = {
            switch developmentMode {
            case .tone: return "tone"
            case .shadow: return "shadow"
            case .comprehensive: return "comprehensive"
            }
        }()
        let modeString = favoriteOnly ? "\(baseModeString)_favorite" : baseModeString
        
        // 获取当前照片数量（根据 favoriteOnly 决定范围）
        let currentPhotoCount: Int
        if favoriteOnly {
            currentPhotoCount = await fetchFavoritePhotoCount()
            print("📊 显影页：只对收藏照片显影，收藏照片数量: \(currentPhotoCount)")
        } else {
            currentPhotoCount = await fetchCurrentPhotoCount()
            print("📊 显影页：全部照片显影，照片数量: \(currentPhotoCount)")
        }
        analyzedPhotoCount = currentPhotoCount
        
        guard currentPhotoCount >= 10 else {
            print("📊 显影页：照片数量不足 10 张，跳过聚类")
            isLoading = false
            return
        }
        
        // 尝试从缓存加载
        if let cache = await coreDataManager.loadDevelopmentClusterCache(mode: modeString) {
            // 检查缓存是否有效（照片数量一致）
            if cache.photoCount == currentPhotoCount {
                print("📊 显影页：使用缓存 (\(modeString), \(cache.clusters.count) 个簇)")
                restoreFromCache(cache: cache, screenSize: screenSize)
                isLoading = false
                return
            } else {
                print("📊 显影页：缓存失效 (照片数 \(cache.photoCount) → \(currentPhotoCount))，重新聚类")
            }
        }
        
        // 缓存不存在或失效，执行聚类
        await performClusteringAndSaveCache(screenSize: screenSize, mode: developmentMode, photoCount: currentPhotoCount, favoriteOnly: favoriteOnly)
    }
    
    /// 从缓存恢复聚类结果
    private func restoreFromCache(cache: CoreDataManager.DevelopmentClusterCache, screenSize: CGSize) {
        let maxPhotoCount = cache.clusters.map { $0.photoCount }.max() ?? 1
        
        if cache.mode == "shadow" {
            // 影调模式：恢复为 TonalSquare
            var squares: [TonalSquare] = []
            for cluster in cache.clusters {
                guard let median = cluster.centroidBrightnessMedian,
                      let contrast = cluster.centroidContrast else { continue }
                
                let normalizedCount = CGFloat(cluster.photoCount) / CGFloat(maxPhotoCount)
                let size = LayoutConstants.tonalMinSize + (LayoutConstants.tonalMaxSize - LayoutConstants.tonalMinSize) * sqrt(normalizedCount)
                
                // 计算圆角半径：对比度 0-100 线性对应 radius 0.5-0
                let clampedContrast = max(0, min(100, contrast))
                let cornerRatio = LayoutConstants.tonalMaxCornerRatio * (1 - CGFloat(clampedContrast) / 100.0)
                let cornerRadius = size * cornerRatio
                
                let padding = size / 2 + 20
                let x = CGFloat.random(in: padding...(screenSize.width - padding))
                let y = CGFloat.random(in: padding...(screenSize.height - padding))
                
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 0.4...0.7)
                let velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
                
                let photos = cluster.photoIdentifiers.map { PhotoInfo(assetIdentifier: $0, distance: 0) }
                
                squares.append(TonalSquare(
                    id: cluster.id,
                    brightnessMedian: median,
                    contrast: contrast,
                    photoCount: cluster.photoCount,
                    position: CGPoint(x: x, y: y),
                    size: size,
                    cornerRadius: cornerRadius,
                    velocity: velocity,
                    photos: photos,
                    noiseOffsetX: CGFloat.random(in: 0...1000),
                    noiseOffsetY: CGFloat.random(in: 0...1000),
                    time: CGFloat.random(in: 0...100)
                ))
                
                // 调试：输出每个圆角矩形的参数（从缓存恢复）
                print("   [缓存] 簇: L=\(String(format: "%.1f", median)), 对比度=\(String(format: "%.1f", contrast)), cornerRadius=\(String(format: "%.1f", cornerRadius)), size=\(String(format: "%.1f", size)), 照片数=\(cluster.photoCount)")
            }
            tonalSquares = squares
        } else {
            // 色调/综合模式：恢复为 ColorCircle
            var circles: [ColorCircle] = []
            for cluster in cache.clusters {
                guard let r = cluster.centroidR,
                      let g = cluster.centroidG,
                      let b = cluster.centroidB_RGB,
                      let L = cluster.centroidL,
                      let a = cluster.centroidA,
                      let B = cluster.centroidB else { continue }
                
                let rgb = SIMD3<Float>(r, g, b)
                let lab = SIMD3<Float>(L, a, B)
                let color = Color(red: Double(r), green: Double(g), blue: Double(b))
                
                let normalizedCount = CGFloat(cluster.photoCount) / CGFloat(maxPhotoCount)
                let radius = 10 + (40 - 10) * sqrt(normalizedCount)
                
                let padding = radius + 20
                let x = CGFloat.random(in: padding...(screenSize.width - padding))
                let y = CGFloat.random(in: padding...(screenSize.height - padding))
                
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let speed = CGFloat.random(in: 0.4...0.7)
                let velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
                
                let photos = cluster.photoIdentifiers.map { PhotoInfo(assetIdentifier: $0, distance: 0) }
                
                circles.append(ColorCircle(
                    id: cluster.id,
                    color: color,
                    rgb: rgb,
                    lab: lab,
                    photoCount: cluster.photoCount,
                    position: CGPoint(x: x, y: y),
                    radius: radius,
                    velocity: velocity,
                    photos: photos,
                    noiseOffsetX: CGFloat.random(in: 0...1000),
                    noiseOffsetY: CGFloat.random(in: 0...1000),
                    time: CGFloat.random(in: 0...100)
                ))
            }
            colorCircles = circles
        }
    }
    
    /// 执行聚类并保存缓存
    private func performClusteringAndSaveCache(screenSize: CGSize, mode: BatchProcessSettings.DevelopmentMode, photoCount: Int, favoriteOnly: Bool = false) async {
        // 获取收藏相册 ID（如果需要）
        let favoriteAlbumIds: Set<String>? = favoriteOnly ? AlbumFavoritesStore.shared.load() : nil
        
        // 构建缓存 key
        let baseModeString: String = {
            switch mode {
            case .tone: return "tone"
            case .shadow: return "shadow"
            case .comprehensive: return "comprehensive"
            }
        }()
        let modeString = favoriteOnly ? "\(baseModeString)_favorite" : baseModeString
        
        if mode == .shadow {
            // 影调模式聚类
            let result = await Task.detached(priority: .userInitiated) { [coreDataManager, kmeans] in
                return ViewModel.performTonalClusteringBackground(
                    coreDataManager: coreDataManager,
                    kmeans: kmeans,
                    screenSize: screenSize,
                    favoriteAlbumIds: favoriteAlbumIds
                )
            }.value
            
            if let error = result.error {
                errorMessage = error
                isLoading = false
                return
            }
            
            tonalSquares = result.squares
            
            // 保存缓存
            let cachedClusters = result.squares.map { square in
                CoreDataManager.DevelopmentClusterCache.CachedCluster(
                    id: square.id,
                    centroidL: nil, centroidA: nil, centroidB: nil,
                    centroidR: nil, centroidG: nil, centroidB_RGB: nil,
                    centroidBrightnessMedian: square.brightnessMedian,
                    centroidContrast: square.contrast,
                    photoCount: square.photoCount,
                    photoIdentifiers: square.photos.map { $0.assetIdentifier }
                )
            }
            
            let cache = CoreDataManager.DevelopmentClusterCache(
                mode: modeString,
                photoCount: photoCount,
                lastUpdated: Date(),
                clusters: cachedClusters
            )
            
            try? await coreDataManager.saveDevelopmentClusterCache(cache)
        } else {
            // 色调/综合模式聚类
            let analysisMode: DevelopmentAnalysisMode = mode == .tone ? .tone : .comprehensive
            
            let result = await Task.detached(priority: .userInitiated) { [coreDataManager, kmeans, converter] in
                return ViewModel.performClusteringBackground(
                    coreDataManager: coreDataManager,
                    kmeans: kmeans,
                    converter: converter,
                    screenSize: screenSize,
                    analysisMode: analysisMode,
                    favoriteAlbumIds: favoriteAlbumIds
                )
            }.value
            
            if let error = result.error {
                errorMessage = error
                isLoading = false
                return
            }
            
            colorCircles = result.circles
            
            // 保存缓存
            let cachedClusters = result.circles.map { circle in
                CoreDataManager.DevelopmentClusterCache.CachedCluster(
                    id: circle.id,
                    centroidL: circle.lab.x, centroidA: circle.lab.y, centroidB: circle.lab.z,
                    centroidR: circle.rgb.x, centroidG: circle.rgb.y, centroidB_RGB: circle.rgb.z,
                    centroidBrightnessMedian: nil,
                    centroidContrast: nil,
                    photoCount: circle.photoCount,
                    photoIdentifiers: circle.photos.map { $0.assetIdentifier }
                )
            }
            
            let cache = CoreDataManager.DevelopmentClusterCache(
                mode: modeString,
                photoCount: photoCount,
                lastUpdated: Date(),
                clusters: cachedClusters
            )
            
            try? await coreDataManager.saveDevelopmentClusterCache(cache)
        }
        
        isLoading = false
    }
    
    // ✅ 旧的聚类方法（保留兼容性，内部调用新方法）
    func performClustering(screenSize: CGSize) async {
        await performClusteringWithCache(screenSize: screenSize)
    }
    
    // 聚类结果结构
    struct ClusteringBackgroundResult {
        let circles: [ColorCircle]
        let photoCount: Int
        let error: String?
    }
    
    // 影调模式聚类结果结构
    struct TonalClusteringBackgroundResult {
        let squares: [TonalSquare]
        let photoCount: Int
        let error: String?
    }
    
    // MARK: - 影调模式聚类（后台线程）
    
    nonisolated private static func performTonalClusteringBackground(
        coreDataManager: CoreDataManager,
        kmeans: SimpleKMeans,
        screenSize: CGSize,
        favoriteAlbumIds: Set<String>? = nil
    ) -> TonalClusteringBackgroundResult {
        // 获取所有照片的明度中位数和对比度
        let (tonalData, photoCount) = fetchTonalDataBackground(coreDataManager: coreDataManager, favoriteAlbumIds: favoriteAlbumIds)
        
        guard photoCount >= 10 else {
            return TonalClusteringBackgroundResult(squares: [], photoCount: photoCount, error: nil)
        }
        
        guard !tonalData.isEmpty else {
            return TonalClusteringBackgroundResult(squares: [], photoCount: photoCount, error: "没有找到影调数据")
        }
        
        print("📊 影调模式聚类：\(tonalData.count) 张照片")
        
        // 将二维数据转换为 SIMD3（z 分量设为 0）
        let points: [SIMD3<Float>] = tonalData.map { data in
            SIMD3<Float>(data.brightnessMedian, data.contrast, 0)
        }
        
        // 自动选择 K 值
        let k = min(max(LayoutConstants.minK, tonalData.count / 10), LayoutConstants.maxK)
        
        // 执行 KMeans 聚类（使用二维距离）
        guard let clusterResult = kmeans.cluster(
            points: points,
            k: k,
            maxIterations: 50,
            colorSpace: .rgb,  // 这里用 rgb 只是为了避免 LAB 转换，实际用的是二维欧几里得距离
            weights: nil,
            analysisMode: .tone  // 使用二维距离
        ) else {
            return TonalClusteringBackgroundResult(squares: [], photoCount: photoCount, error: "聚类失败")
        }
        
        // 将照片分配到簇
        var clusterToPhotos: [Int: [(assetId: String, distance: Float)]] = [:]
        
        for (index, data) in tonalData.enumerated() {
            let clusterIndex = clusterResult.assignments[index]
            let centroid = clusterResult.centroids[clusterIndex]
            let point = points[index]
            
            // 计算二维距离
            let dx = point.x - centroid.x
            let dy = point.y - centroid.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if clusterToPhotos[clusterIndex] == nil {
                clusterToPhotos[clusterIndex] = []
            }
            clusterToPhotos[clusterIndex]?.append((assetId: data.assetIdentifier, distance: distance))
        }
        
        let maxPhotoCount = clusterToPhotos.values.map { $0.count }.max() ?? 1
        
        var squares: [TonalSquare] = []
        squares.reserveCapacity(clusterResult.centroids.count)
        
        for (clusterIndex, centroid) in clusterResult.centroids.enumerated() {
            guard let photos = clusterToPhotos[clusterIndex], !photos.isEmpty else {
                continue
            }
            
            let brightnessMedian = centroid.x  // 明度中位数
            let contrast = centroid.y          // 对比度
            
            // 计算边长（与照片数量相关）
            let normalizedCount = CGFloat(photos.count) / CGFloat(maxPhotoCount)
            let size = LayoutConstants.tonalMinSize + (LayoutConstants.tonalMaxSize - LayoutConstants.tonalMinSize) * sqrt(normalizedCount)
            
            // 计算圆角半径：对比度 0-100 线性对应 radius 0.5-0
            let clampedContrast = max(0, min(100, contrast))
            let cornerRatio = LayoutConstants.tonalMaxCornerRatio * (1 - CGFloat(clampedContrast) / 100.0)
            let cornerRadius = size * cornerRatio
            
            // 随机初始位置
            let padding = size / 2 + 20
            let x = CGFloat.random(in: padding...(screenSize.width - padding))
            let y = CGFloat.random(in: padding...(screenSize.height - padding))
            
            // 随机初始速度
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let speed = CGFloat.random(in: 0.4...0.7)
            let velocity = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
            
            let clusterPhotos = photos
                .map { PhotoInfo(assetIdentifier: $0.assetId, distance: $0.distance) }
                .sorted { $0.distance < $1.distance }
            
            squares.append(TonalSquare(
                id: UUID(),
                brightnessMedian: brightnessMedian,
                contrast: contrast,
                photoCount: photos.count,
                position: CGPoint(x: x, y: y),
                size: size,
                cornerRadius: cornerRadius,
                velocity: velocity,
                photos: clusterPhotos,
                noiseOffsetX: CGFloat.random(in: 0...1000),
                noiseOffsetY: CGFloat.random(in: 0...1000),
                time: CGFloat.random(in: 0...100)
            ))
            
            // 调试：输出每个圆角矩形的参数
            print("   簇\(clusterIndex + 1): L=\(String(format: "%.1f", brightnessMedian)), 对比度=\(String(format: "%.1f", contrast)), cornerRadius=\(String(format: "%.1f", cornerRadius)), size=\(String(format: "%.1f", size)), 照片数=\(photos.count)")
        }
        
        print("📊 影调模式聚类完成：\(squares.count) 个簇")
        
        return TonalClusteringBackgroundResult(squares: squares, photoCount: photoCount, error: nil)
    }
    
    // 获取影调数据（后台线程）
    nonisolated private static func fetchTonalDataBackground(coreDataManager: CoreDataManager, favoriteAlbumIds: Set<String>? = nil) -> ([TonalPhotoData], Int) {
        let context = coreDataManager.newBackgroundContext()
        var tonalData: [TonalPhotoData] = []
        var photoCount = 0
        
        context.performAndWait {
            let request = PhotoAnalysisEntity.fetchRequest()
            request.propertiesToFetch = [
                "assetLocalIdentifier",
                "albumIdentifier",
                "brightnessMedian",
                "brightnessContrast",
                "brightnessCDF"
            ]
            
            // 如果指定了收藏相册，添加过滤条件
            if let favoriteIds = favoriteAlbumIds, !favoriteIds.isEmpty {
                request.predicate = NSPredicate(format: "albumIdentifier IN %@", favoriteIds)
                print("📊 影调模式：只聚类收藏照片集 (\(favoriteIds.count) 个相册)")
            }
            
            do {
                let results = try context.fetch(request)
                photoCount = results.count
                tonalData.reserveCapacity(photoCount)
                
                for entity in results {
                    guard let assetId = entity.assetLocalIdentifier else { continue }
                    
                    var median = entity.brightnessMedian
                    var contrast = entity.brightnessContrast
                    
                    // 如果没有预计算的值，尝试从 CDF 计算
                    if (median == 0 && contrast == 0), let cdfData = entity.brightnessCDF {
                        let cdf = cdfData.withUnsafeBytes { ptr in
                            Array(ptr.bindMemory(to: Float.self))
                        }
                        
                        if cdf.count == 256 {
                            // 计算中位数
                            for (index, value) in cdf.enumerated() {
                                if value >= 0.5 {
                                    median = Float(index) / 255.0 * 100.0
                                    break
                                }
                            }
                            
                            // 计算对比度
                            var p5Index = 0
                            var p95Index = 255
                            for (index, value) in cdf.enumerated() {
                                if value >= 0.05 && p5Index == 0 {
                                    p5Index = index
                                }
                                if value >= 0.95 {
                                    p95Index = index
                                    break
                                }
                            }
                            contrast = Float(p95Index - p5Index) / 255.0 * 100.0
                        }
                    }
                    
                    // 只添加有效数据
                    if median > 0 || contrast > 0 {
                        tonalData.append(TonalPhotoData(
                            assetIdentifier: assetId,
                            brightnessMedian: median,
                            contrast: contrast
                        ))
                    }
                }
                
                print("📊 影调数据加载：\(tonalData.count)/\(photoCount) 张照片有有效数据")
                
                // 调试：输出对比度分布
                if !tonalData.isEmpty {
                    let contrasts = tonalData.map { $0.contrast }
                    let minContrast = contrasts.min() ?? 0
                    let maxContrast = contrasts.max() ?? 0
                    let avgContrast = contrasts.reduce(0, +) / Float(contrasts.count)
                    let below15 = contrasts.filter { $0 <= 15 }.count
                    let between15and60 = contrasts.filter { $0 > 15 && $0 < 60 }.count
                    let above60 = contrasts.filter { $0 >= 60 }.count
                    print("📊 对比度分布统计:")
                    print("   最小: \(minContrast), 最大: \(maxContrast), 平均: \(avgContrast)")
                    print("   ≤15: \(below15)张, 15-60: \(between15and60)张, ≥60: \(above60)张")
                }
            } catch {
                print("❌ 获取影调数据失败: \(error)")
            }
        }
        
        return (tonalData, photoCount)
    }
    
    // MARK: - 距离计算
    
    /// 根据模式计算距离
    nonisolated private static func calculateDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>, analysisMode: DevelopmentAnalysisMode) -> Float {
        if analysisMode == .tone {
            return euclideanDistance2D(a, b)
        } else {
            return euclideanDistance(a, b)
        }
    }
    
    /// 欧几里得距离（三维，L, a, b）
    nonisolated private static func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    /// 欧几里得距离（二维，只用 a, b）
    nonisolated private static func euclideanDistance2D(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diffA = a.y - b.y  // a 分量
        let diffB = a.z - b.z  // b 分量
        return sqrt(diffA * diffA + diffB * diffB)
    }
    
    // ✅ 后台线程执行聚类计算（内存优化版）
    nonisolated private static func performClusteringBackground(
        coreDataManager: CoreDataManager,
        kmeans: SimpleKMeans,
        converter: ColorSpaceConverter,
        screenSize: CGSize,
        analysisMode: DevelopmentAnalysisMode = .comprehensive,
        favoriteAlbumIds: Set<String>? = nil
    ) -> ClusteringBackgroundResult {
        // 获取颜色数据和预存储的视觉代表色
        let (colorSources, photoCount, storedVisualColors) = fetchColorsWithSourceBackground(coreDataManager: coreDataManager, favoriteAlbumIds: favoriteAlbumIds)
        
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
            weights: weights,
            analysisMode: analysisMode
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
                let distance = calculateDistance(visualColorLAB, centroid, analysisMode: analysisMode)
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
    nonisolated private static func fetchColorsWithSourceBackground(coreDataManager: CoreDataManager, favoriteAlbumIds: Set<String>? = nil) -> ([ColorWithSource], Int, [String: SIMD3<Float>]) {
        let context = coreDataManager.newBackgroundContext()
        var colorSources: [ColorWithSource] = []
        var photoCount = 0
        var photoVisualColors: [String: SIMD3<Float>] = [:]  // 存储每张照片的视觉代表色
        
        context.performAndWait {
            let request = PhotoAnalysisEntity.fetchRequest()
            // 获取需要的属性
            request.propertiesToFetch = [
                "assetLocalIdentifier",
                "albumIdentifier",
                "dominantColors",
                "visualRepresentativeColorR",
                "visualRepresentativeColorG",
                "visualRepresentativeColorB"
            ]
            
            // 如果指定了收藏相册，添加过滤条件
            if let favoriteIds = favoriteAlbumIds, !favoriteIds.isEmpty {
                request.predicate = NSPredicate(format: "albumIdentifier IN %@", favoriteIds)
                print("📊 色调/综合模式：只聚类收藏照片集 (\(favoriteIds.count) 个相册)")
            }
        
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
    
    // ✅ Perlin Noise 驱动的运动逻辑（色调/综合模式）
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
    
    // ✅ Perlin Noise 驱动的运动逻辑（影调模式）
    func updateTonalSquareMotion(screenSize: CGSize) {
        for i in 0..<tonalSquares.count {
            var s = tonalSquares[i]
            
            // 更新时间
            s.time += PerlinMotion.timeScale
            
            // 使用 Perlin Noise 计算速度方向
            let noiseX = PerlinNoise.noise2D(
                x: s.position.x * PerlinMotion.noiseScale + s.noiseOffsetX,
                y: s.time
            )
            let noiseY = PerlinNoise.noise2D(
                x: s.position.y * PerlinMotion.noiseScale + s.noiseOffsetY,
                y: s.time + 100
            )
            
            // 将噪声值映射到速度
            s.velocity.x = noiseX * PerlinMotion.maxSpeed
            s.velocity.y = noiseY * PerlinMotion.maxSpeed
            
            // 更新位置
            s.position.x += s.velocity.x
            s.position.y += s.velocity.y
            
            // 边界处理：软回弹
            let pad = s.size / 2 + PerlinMotion.boundaryPadding
            
            if s.position.x < pad {
                s.position.x = pad
                s.velocity.x = abs(s.velocity.x) * PerlinMotion.boundarySoftness
            }
            if s.position.x > screenSize.width - pad {
                s.position.x = screenSize.width - pad
                s.velocity.x = -abs(s.velocity.x) * PerlinMotion.boundarySoftness
            }
            if s.position.y < pad {
                s.position.y = pad
                s.velocity.y = abs(s.velocity.y) * PerlinMotion.boundarySoftness
            }
            if s.position.y > screenSize.height - pad {
                s.position.y = screenSize.height - pad
                s.velocity.y = -abs(s.velocity.y) * PerlinMotion.boundarySoftness
            }
            
            tonalSquares[i] = s
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
    
    // 影调模式：圆角正方形发光效果
    private func glowingSquareGlow(square: ViewModel.TonalSquare) -> some View {
        let s = square.size
        let cr = square.cornerRadius
        
        return ZStack {
            // 外层发光效果
            RoundedRectangle(cornerRadius: cr * 2)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            square.grayColor.opacity(0.35),
                            square.grayColor.opacity(0.15),
                            .clear
                        ]),
                        center: .center,
                        startRadius: s * 0.15,
                        endRadius: s * 1.1
                    )
                )
                .frame(width: s * 2.2, height: s * 2.2)
                .blendMode(.screen)
            
            // 中层模糊
            RoundedRectangle(cornerRadius: cr * 1.2)
                .fill(square.grayColor)
                .frame(width: s * 1.2, height: s * 1.2)
                .blur(radius: s * 0.12)
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
            Image(systemName: viewModel.isFavoriteOnly ? "heart" : "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.4))
            
            if viewModel.isFavoriteOnly {
                Text("收藏 10 张照片后开启色彩显影")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                if viewModel.analyzedPhotoCount > 0 {
                    Text("当前已收藏 \(viewModel.analyzedPhotoCount) 张")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
            } else {
                Text("扫描 10 张照片开启色彩显影")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                if viewModel.analyzedPhotoCount > 0 {
                    Text("当前已扫描 \(viewModel.analyzedPhotoCount) 张")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
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
