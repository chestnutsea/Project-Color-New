#if canImport(UIKit)
import SwiftUI
import Photos
import PhotosUI
import UIKit
import Combine

struct SearchColorView: View {
    // MARK: - Layout Constants
    private let selectorTopPadding: CGFloat = 30
    private let selectorHorizontalPadding: CGFloat = 20
    private let selectorHeight: CGFloat = 52
    private let selectorCornerRadius: CGFloat = 18
    private let selectorBorderWidth: CGFloat = 1
    private let plusIconSize: CGFloat = 50
    private let photoCardWidth: CGFloat = 150
    private let cardCornerRadius: CGFloat = 6
    private let stackShadowColor = Color.black.opacity(0.25)
    private let stackShadowRadius: CGFloat = 12
    private let stackShadowOffsetX: CGFloat = 4
    private let stackShadowOffsetY: CGFloat = 6
    private let middleAngles: [Double] = [-6, 6]
    private let middleOffsetsX: [CGFloat] = [-25, 25]
    private let bottomAngles: [Double] = [-8, 6, -4]
    private let bottomOffsetsX: [CGFloat] = [-35, 35, -10]
    private let bottomOffsetsY: [CGFloat] = [0, 20, 40]
    private let gridSpacing: CGFloat = 10
    private let gridPadding: CGFloat = 20
    
    private var resultColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
    }
    
    // MARK: - Color Category
    private enum ColorCategory: String, CaseIterable, Identifiable {
        case white, black, gray, red, orange, yellow, green, cyan, blue, purple
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .white: return "白色"
            case .black: return "黑色"
            case .gray: return "灰色"
            case .red: return "红色"
            case .orange: return "橙色"
            case .yellow: return "黄色"
            case .green: return "绿色"
            case .cyan: return "青色"
            case .blue: return "蓝色"
            case .purple: return "紫色"
            }
        }
        
        func matches(h: Float, s: Float, l: Float) -> Bool {
            let hue = ((h.truncatingRemainder(dividingBy: 360)) + 360)
                .truncatingRemainder(dividingBy: 360)
            
            if s <= 0.1 {
                switch self {
                case .white: return l >= 0.85
                case .black: return l <= 0.15
                case .gray: return l > 0.15 && l < 0.85
                default: return false
                }
            }
            
            switch self {
            case .red: return hue >= 340 || hue < 20
            case .orange: return hue >= 20 && hue < 40
            case .yellow: return hue >= 40 && hue < 70
            case .green: return hue >= 70 && hue < 160
            case .cyan: return hue >= 160 && hue < 200
            case .blue: return hue >= 200 && hue < 260
            case .purple: return hue >= 260 && hue < 320
            case .white, .black, .gray: return false
            }
        }
    }
    
    private struct FilteredPhoto: Identifiable, Equatable {
        let id = UUID()
        let assetIdentifier: String
        let image: UIImage
    }
    
    private struct ProcessSignature: Equatable {
        let category: ColorCategory
        let assetIdentifiers: [String]
    }
    
    // MARK: - State
    @State private var selectedCategory: ColorCategory? = nil
    @State private var showPhotoPicker = false
    @State private var showImageViewer = false
    @State private var viewerIndex = 0
    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @StateObject private var selectionManager = SelectedPhotosManager.shared
    
    @State private var selectedAssets: [PHAsset] = []
    @State private var selectedImages: [UIImage] = []
    @State private var filteredPhotos: [FilteredPhoto] = []
    
    @State private var isProcessing = false
    @State private var progressStage: String = ""
    @State private var progressDetail: String = ""
    
    @State private var currentProcessingSignature: ProcessSignature?
    @State private var lastCompletedSignature: ProcessSignature?
    @State private var processingTask: Task<Void, Never>? = nil
    
    // MARK: - Body
    var body: some View {
        mainContent
            .navigationTitle(L10n.Lab.searchColor.localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { results in
                    selectionManager.updateSelectedAssets(with: results)
                    loadSelectedAssets()
                }
            }
            .fullScreenCover(isPresented: $showImageViewer) {
                imageViewer
            }
            .onAppear {
                // ⚠️ 不检查照片库权限，保持隐私模式
                // checkPhotoLibraryStatus()
                loadSelectedAssets()
            }
            .onDisappear {
                processingTask?.cancel()
                processingTask = nil
            }
            .onChange(of: selectionManager.selectedAssetIdentifiers) { _ in
                lastCompletedSignature = nil
                loadSelectedAssets()
            }
            .onChange(of: selectedCategory) { _ in
                lastCompletedSignature = nil
                triggerProcessingIfNeeded()
            }
            .onChange(of: selectedAssets) { _ in
                triggerProcessingIfNeeded()
            }
    }
    
    private var mainContent: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            scrollContent
            
            if isProcessing {
                processingOverlay
            }
        }
    }
    
    private var scrollContent: some View {
        GeometryReader { geometry in
            ScrollView {
                contentVStack(geometry: geometry)
            }
        }
    }
    
    private func contentVStack(geometry: GeometryProxy) -> some View {
        VStack(spacing: 28) {
            selectorView
            
            Color.clear
                .frame(height: max(0, geometry.size.height * 0.1))
            
            photoSelectionView
            
            if !filteredPhotos.isEmpty {
                resultsSection
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, selectorTopPadding)
        .padding(.horizontal, selectorHorizontalPadding)
        .padding(.bottom, 40)
    }
    
    private var photoSelectionView: some View {
        Group {
            if selectedImages.isEmpty {
                addButton
            } else {
                PhotoStackView(images: selectedImages)
                    .padding(.top, 12)
                    .onTapGesture { handleAddButtonTapped() }
            }
        }
    }
    
    // MARK: - Selector
    private var selectorView: some View {
        RoundedRectangle(cornerRadius: selectorCornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: selectorCornerRadius, style: .continuous)
                    .stroke(Color(.separator), lineWidth: selectorBorderWidth)
            )
            .frame(height: selectorHeight)
            .overlay(
                HStack(spacing: 16) {
                    Text("我想找")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Picker("颜色分类", selection: $selectedCategory) {
                        Text("请选择").tag(ColorCategory?.none)
                        ForEach(ColorCategory.allCases) { category in
                            Text(category.displayName).tag(ColorCategory?.some(category))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                .padding(.horizontal, 20)
            )
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button(action: handleAddButtonTapped) {
            Image(systemName: "plus.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: plusIconSize, height: plusIconSize)
                .foregroundStyle(Color.blue, Color.white)
                .shadow(radius: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Results
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(format: L10n.SearchColor.matchedPhotos.localized, filteredPhotos.count))
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, gridPadding)
            
            LazyVGrid(columns: resultColumns, spacing: gridSpacing) {
                ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                    GeometryReader { geo in
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(radius: 2)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        viewerIndex = index
                        showImageViewer = true
                    }
                }
            }
            .padding(.horizontal, gridPadding)
        }
    }
    
    private var imageViewer: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            if !filteredPhotos.isEmpty {
                TabView(selection: $viewerIndex) {
                    ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                        Image(uiImage: photo.image)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            
            Button {
                showImageViewer = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.85))
                    .padding()
            }
        }
    }
    
    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 12) {
                Text(progressStage)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(progressDetail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Color.white.opacity(0.95))
            .cornerRadius(16)
            .shadow(radius: 10)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
    
    // MARK: - Actions
    private func handleAddButtonTapped() {
        // ✅ PHPicker 不需要权限，直接显示照片选择器
        showPhotoPicker = true
    }
    
    private func checkPhotoLibraryStatus() {
        photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    private func loadSelectedAssets() {
        let assets = selectionManager.selectedAssets
        selectedAssets = assets
        
        Task {
            let latest = Array(assets.suffix(3))
            var images: [UIImage] = []
            for asset in latest {
                if let image = await requestImage(for: asset, targetSize: CGSize(width: 600, height: 600)) {
                    images.append(image)
                }
            }
            await MainActor.run {
                selectedImages = images
            }
        }
    }
    
    private func triggerProcessingIfNeeded() {
        guard let category = selectedCategory, !selectedAssets.isEmpty else {
            return
        }
        
        let identifiers = selectedAssets.map { $0.localIdentifier }.sorted()
        let signature = ProcessSignature(category: category, assetIdentifiers: identifiers)
        
        if signature == currentProcessingSignature { return }
        if signature == lastCompletedSignature { return }
        
        startProcessing(with: signature)
    }
    
    private func startProcessing(with signature: ProcessSignature) {
        processingTask?.cancel()
        processingTask = Task {
            await MainActor.run {
                currentProcessingSignature = signature
                isProcessing = true
                progressStage = "提取主色"
                progressDetail = ""
                filteredPhotos.removeAll()
            }
            
            let assets = selectedAssets
            let total = assets.count
            let extractor = SimpleColorExtractor()
            let converter = ColorSpaceConverter()
            var matchedPhotos: [FilteredPhoto] = []
            var matchedIdentifiers = Set<String>()
            
            for (index, asset) in assets.enumerated() {
                if Task.isCancelled { break }
                
                await MainActor.run {
                    progressStage = "提取主色"
                    progressDetail = "正在分析第 \(index + 1)/\(total) 张照片"
                }
                
                guard let image = await requestImage(for: asset, targetSize: CGSize(width: 512, height: 512)),
                      let cgImage = normalizedCGImage(from: image) else {
                    continue
                }
                
                let dominantColors = extractor.extractDominantColors(from: cgImage, count: 5)
                
                // 只匹配权重最高的主色（第一个）
                if let topColor = dominantColors.first {
                    let hsl = converter.rgbToHSL(topColor.rgb)
                    let matched = signature.category.matches(h: hsl.h, s: hsl.s, l: hsl.l)
                    
                    if matched && !matchedIdentifiers.contains(asset.localIdentifier) {
                        matchedIdentifiers.insert(asset.localIdentifier)
                        matchedPhotos.append(FilteredPhoto(assetIdentifier: asset.localIdentifier, image: image))
                    }
                }
            }
            
            if Task.isCancelled {
                await MainActor.run {
                    isProcessing = false
                    currentProcessingSignature = nil
                }
                return
            }
            
            await MainActor.run {
                filteredPhotos = matchedPhotos
                isProcessing = false
                lastCompletedSignature = signature
                currentProcessingSignature = nil
            }
        }
    }
    
    // MARK: - Helpers
    private func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var hasResumed = false  // ✅ 防止重复 resume
            let manager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: image)
            }
        }
    }
    
    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }
}

#else

import SwiftUI

struct SearchColorView: View {
    var body: some View {
        Text(L10n.SearchColor.iosOnly.localized)
            .font(.headline)
            .foregroundColor(.secondary)
            .padding()
    }
}

#endif
#Preview {
    SearchColorView()
}
