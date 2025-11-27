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

// MARK: - Apple 风真实漂流运动参数

private enum AppleMotion {
    static let damping: CGFloat = 1        // 极弱阻尼 → 可长期漂流
    static let driftStrength: CGFloat = 0.002  // 极小扰动 → 防止死直线
    static let maxSpeed: CGFloat = 0.5         // 最大速度
    static let boundarySoftness: CGFloat = 0.85 // 软回弹
}

// MARK: - 主视图（EmergeView）

struct EmergeView: View {
    
    @StateObject private var viewModel = ViewModel()
    @State private var screenSize: CGSize = .zero
    @State private var isAnimating = false
    @State private var selectedCircleID: UUID? = nil  // 选中的圆形 ID
    @State private var fullScreenPhotoIndex: Int? = nil  // 全屏查看的照片索引
    @State private var fullScreenPhotos: [ViewModel.PhotoInfo] = []  // 全屏查看的照片列表
    @Namespace private var heroNamespace  // Hero animation namespace
    
    // ✅ 锚点状态：记录点击时圆形的位置和半径
    @State private var anchorPosition: CGPoint = .zero
    @State private var anchorRadius: CGFloat = 0
    @State private var anchorColor: Color = .clear
    @State private var anchorPhotos: [ViewModel.PhotoInfo] = []
    
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
                                    
                                    // 暂停动画
                                    isAnimating = false
                                    
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        selectedCircleID = circle.id
                                    }
                                }
                        }
                    }
                }
                
                // ✅ Hero 动画锚点（未选中时在圆形位置，选中时变为详情视图）
                if selectedCircleID == nil && anchorRadius > 0 {
                    // 未选中：锚点圆形（不可见，用于动画目标）
                    Circle()
                        .fill(anchorColor)
                        .frame(width: anchorRadius * 2, height: anchorRadius * 2)
                        .position(anchorPosition)
                        .matchedGeometryEffect(id: "hero-anchor", in: heroNamespace)
                        .opacity(0)
                }
                
                // ✅ 详情视图（选中时显示）
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
                isAnimating = false
                viewModel.reset()
                
                Task {
                    await viewModel.performClustering(screenSize: geometry.size)
                }
            }
            .onChange(of: viewModel.isLoading) { isLoading in
                if !isLoading && !viewModel.colorCircles.isEmpty {
                    isAnimating = true
                }
            }
            .onReceive(timer) { _ in
                guard isAnimating else { return }
                viewModel.updateAppleStyleMotion(
                    screenSize: screenSize,
                    damping: AppleMotion.damping,
                    drift: AppleMotion.driftStrength,
                    maxSpeed: AppleMotion.maxSpeed,
                    boundarySoftness: AppleMotion.boundarySoftness
                )
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
    
    // ✅ 聚类逻辑：使用 assignments 直接追溯照片归属
    func performClustering(screenSize: CGSize) async {
        isLoading = true
        errorMessage = nil
        colorCircles = []
        
        // 获取带来源的颜色信息
        let colorSources = fetchColorsWithSource()
        
        guard analyzedPhotoCount >= 10 else {
            isLoading = false
            return
        }
        
        guard !colorSources.isEmpty else {
            isLoading = false
            errorMessage = "没有找到颜色数据"
            return
        }
        
        // ✅ 转换为 LAB 并计算二次加权
        let labColors = colorSources.map { converter.rgbToLab($0.rgb) }
        let weights: [Float] = zip(colorSources, labColors).map { (colorSource, lab) in
            let L = lab.x  // L* 值
            let chroma = sqrt(lab.y * lab.y + lab.z * lab.z)  // sqrt(a² + b²)
            
            // ① 饱和度权重
            let chromaFactor: Float = chroma < LayoutConstants.chromaThreshold 
                ? LayoutConstants.lowChromaFactor : 1.0
            
            // ② 深暗惩罚
            let darkFactor: Float = L < LayoutConstants.darkLThreshold 
                ? LayoutConstants.darkFactor : 1.0
            
            // ③ 高亮奖励
            let brightFactor: Float = L > LayoutConstants.brightLThreshold 
                ? LayoutConstants.brightFactor : 1.0
            
            return colorSource.weight * chromaFactor * darkFactor * brightFactor
        }
        
        let k = min(max(LayoutConstants.minK, colorSources.count / 50), LayoutConstants.maxK)
        
        guard let result = kmeans.cluster(
            points: labColors,
            k: k,
            maxIterations: 50,
            colorSpace: .lab,
            weights: weights
        ) else {
            isLoading = false
            errorMessage = "聚类失败"
            return
        }
        
        // ✅ 每张照片只属于一个簇：根据"视觉主色"到所有簇质心的距离，选最近的
        // 视觉主色：visual_score 最高的主色
        var photoVisualColor: [String: SIMD3<Float>] = [:]  // 照片 -> 视觉主色的 LAB 值
        var photoColors: [String: [(lab: SIMD3<Float>, weight: Float)]] = [:]  // 临时存储每张照片的所有主色
        
        // 收集每张照片的所有主色
        for colorSource in colorSources {
            let assetId = colorSource.assetIdentifier
            let lab = converter.rgbToLab(colorSource.rgb)
            
            if photoColors[assetId] == nil {
                photoColors[assetId] = []
            }
            photoColors[assetId]?.append((lab: lab, weight: colorSource.weight))
        }
        
        // 为每张照片选择视觉主色（visual_score 最高的）
        for (assetId, colors) in photoColors {
            // 计算每个主色的 visual_score
            let colorsWithScore = colors.map { color -> (lab: SIMD3<Float>, score: Float) in
                let L = color.lab.x
                let chroma = sqrt(color.lab.y * color.lab.y + color.lab.z * color.lab.z)
                let weight = color.weight
                
                // ① 饱和度权重
                let chromaFactor: Float = chroma < LayoutConstants.chromaThreshold 
                    ? LayoutConstants.lowChromaFactor : 1.0
                
                // ② 深暗惩罚
                let darkFactor: Float = L < LayoutConstants.darkLThreshold 
                    ? LayoutConstants.darkFactor : 1.0
                
                // ③ 高亮奖励
                let brightFactor: Float = L > LayoutConstants.brightLThreshold 
                    ? LayoutConstants.brightFactor : 1.0
                
                // ④ 小面积惩罚
                let areaFactor: Float = weight < LayoutConstants.smallAreaThreshold 
                    ? LayoutConstants.smallAreaFactor : 1.0
                
                let visualScore = weight * chromaFactor * darkFactor * brightFactor * areaFactor
                return (lab: color.lab, score: visualScore)
            }
            
            // 选 visual_score 最高的作为视觉主色
            if let visualColor = colorsWithScore.max(by: { $0.score < $1.score }) {
                photoVisualColor[assetId] = visualColor.lab
            }
        }
        
        // 聚类完成后，重新计算每张照片的视觉主色到所有簇质心的距离，选最近的
        var clusterToPhotos: [Int: [(assetId: String, distance: Float)]] = [:]
        
        for (assetId, visualColorLAB) in photoVisualColor {
            // 找到距离最近的簇
            var minDistance: Float = .infinity
            var nearestClusterIndex = 0
            
            for (clusterIndex, centroid) in result.centroids.enumerated() {
                let distance = converter.deltaE(visualColorLAB, centroid)
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
        
        // 计算最大照片数（用于归一化圆形大小）
        let maxPhotoCount = clusterToPhotos.values.map { $0.count }.max() ?? 1
        
        var circles: [ColorCircle] = []
        
        for (clusterIndex, centroidLAB) in result.centroids.enumerated() {
            // ✅ 获取该簇的照片
            guard let photos = clusterToPhotos[clusterIndex], !photos.isEmpty else {
                continue  // 跳过没有照片的簇
            }
            
            let centroidRGB = converter.labToRgb(centroidLAB)
            let color = Color(
                red: Double(centroidRGB.x),
                green: Double(centroidRGB.y),
                blue: Double(centroidRGB.z)
            )
            
            // ✅ 圆形大小基于照片数量
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
            
            // ✅ 构建照片列表，按第一个主色到质心的距离排序
            let clusterPhotos = photos
                .map { PhotoInfo(assetIdentifier: $0.assetId, distance: $0.distance) }
                .sorted { $0.distance < $1.distance }
            
            circles.append(ColorCircle(
                color: color,
                rgb: centroidRGB,
                lab: centroidLAB,
                photoCount: photos.count,
                position: CGPoint(x: x, y: y),
                radius: radius,
                velocity: velocity,
                photos: clusterPhotos
            ))
        }
        
        colorCircles = circles
        isLoading = false
    }
    
    // ✅ 获取带来源的颜色信息
    private func fetchColorsWithSource() -> [ColorWithSource] {
        let context = coreDataManager.viewContext
        let request = PhotoAnalysisEntity.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            analyzedPhotoCount = results.count
            
            var colorSources: [ColorWithSource] = []
            
            for entity in results {
                guard let assetId = entity.assetLocalIdentifier,
                      let data = entity.dominantColors,
                      let colors = try? JSONDecoder().decode([DominantColor].self, from: data) else {
                    continue
                }
                
                // 每个颜色都记录来源照片
                for color in colors {
                    colorSources.append(ColorWithSource(
                        rgb: color.rgb,
                        weight: color.weight,
                        assetIdentifier: assetId
                    ))
                }
            }
            return colorSources
        } catch {
            errorMessage = "获取数据失败"
            return []
        }
    }
    
    // ✅ 真实漂流运动逻辑（由外部参数驱动）
    func updateAppleStyleMotion(
        screenSize: CGSize,
        damping: CGFloat,
        drift: CGFloat,
        maxSpeed: CGFloat,
        boundarySoftness: CGFloat
    ) {
        for i in 0..<colorCircles.count {
            var c = colorCircles[i]
            
            c.velocity.x *= damping
            c.velocity.y *= damping
            
            c.velocity.x += CGFloat.random(in: -drift...drift)
            c.velocity.y += CGFloat.random(in: -drift...drift)
            
            c.velocity.x = max(min(c.velocity.x, maxSpeed), -maxSpeed)
            c.velocity.y = max(min(c.velocity.y, maxSpeed), -maxSpeed)
            
            c.position.x += c.velocity.x
            c.position.y += c.velocity.y
            
            let pad = c.radius + 16
            
            if c.position.x < pad {
                c.position.x = pad
                c.velocity.x = abs(c.velocity.x) * boundarySoftness
            }
            if c.position.x > screenSize.width - pad {
                c.position.x = screenSize.width - pad
                c.velocity.x = -abs(c.velocity.x) * boundarySoftness
            }
            if c.position.y < pad {
                c.position.y = pad
                c.velocity.y = abs(c.velocity.y) * boundarySoftness
            }
            if c.position.y > screenSize.height - pad {
                c.position.y = screenSize.height - pad
                c.velocity.y = -abs(c.velocity.y) * boundarySoftness
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        selectedCircleID = nil
                    }
                    // ✅ 恢复动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimating = true
                    }
                }
            
            // 详情矩形（带 Hero 动画）
            detailContentView()
                .matchedGeometryEffect(id: "hero-anchor", in: heroNamespace)
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
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.cornerRadius))
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 下滑关闭
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            selectedCircleID = nil
                        }
                        // ✅ 恢复动画
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isAnimating = true
                        }
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
        .clipShape(RoundedRectangle(cornerRadius: LayoutConstants.cornerRadius))
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
        withAnimation(.easeOut(duration: 0.2)) {
            backgroundOpacity = 0
            imageScale = 0.8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - ✅ 单张照片视图（简化版，避免手势冲突）

struct SinglePhotoView: View {
    let assetIdentifier: String
    @State private var image: UIImage?
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = scale > 1.0 ? 1.0 : 2.0
                            }
                        }
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
            
            Text("上传 10 张照片开启色彩显影")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            if viewModel.analyzedPhotoCount > 0 {
                Text("当前已分析 \(viewModel.analyzedPhotoCount) 张")
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
