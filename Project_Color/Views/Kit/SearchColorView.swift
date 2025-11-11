#if canImport(UIKit)
import SwiftUI
import Photos
import UIKit

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
    @State private var showAlbumList = false
    @State private var showImageViewer = false
    @State private var viewerIndex = 0
    @State private var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @StateObject private var selectionManager = PhotoSelectionManager.shared
    
    @State private var selectedAssets: [PHAsset] = []
    @State private var selectedImages: [UIImage] = []
    @State private var filteredPhotos: [FilteredPhoto] = []
    
    @State private var isProcessing = false
    @State private var progressStage: String = ""
    @State private var progressDetail: String = ""
    @State private var processingProgress: Double = 0
    
    @State private var currentProcessingSignature: ProcessSignature?
    @State private var lastCompletedSignature: ProcessSignature?
    @State private var processingTask: Task<Void, Never>? = nil
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 28) {
                        selectorView
                        
                        Color.clear
                            .frame(height: max(0, geometry.size.height * 0.1))
                        
                        addButton
                        
                        if !selectedImages.isEmpty {
                            photoStackView
                                .padding(.top, 12)
                                .onTapGesture { handleAddButtonTapped() }
                        }
                        
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
            }
            
            if isProcessing {
                processingOverlay
            }
        }
        .navigationTitle("寻色")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAlbumList) {
            AlbumListView()
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            imageViewer
        }
        .onAppear(perform: checkPhotoLibraryStatus)
        .onDisappear {
            processingTask?.cancel()
            processingTask = nil
        }
        .onChange(of: selectionManager.selectedAlbums) { _ in
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
                .frame(width: plusIcon