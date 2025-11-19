//
//  AlbumListView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//

import SwiftUI

struct AlbumListView: View {
    @StateObject private var viewModel = AlbumViewModel()
    @StateObject private var selectionManager = PhotoSelectionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 布局常量
    private let horizontalPadding: CGFloat = 15 // 左右边距
    private let spacing: CGFloat = 20 // 中间间距
    
    // 当前显示选项的相册 ID
    @State private var showingOptionsForAlbumId: String? = nil
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let columns = 2
                let totalSpacing = spacing * CGFloat(columns - 1)
                let totalPadding = horizontalPadding * 2
                let cardSize = max(120, floor((geometry.size.width - totalSpacing - totalPadding) / CGFloat(columns)))
                
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                        spacing: spacing
                    ) {
                        ForEach(viewModel.albums) { album in
                            AlbumCardView(
                                album: album,
                                cardSize: cardSize,
                                cornerRadius: viewModel.cardCornerRadius,
                                isSelected: selectionManager.isAlbumSelected(album),
                                showOptions: showingOptionsForAlbumId == album.id,
                                onTap: {
                                    if selectionManager.isAlbumSelected(album) {
                                        selectionManager.toggleAlbumSelection(album)
                                        showingOptionsForAlbumId = nil
                                    } else {
                                        showingOptionsForAlbumId = (showingOptionsForAlbumId == album.id) ? nil : album.id
                                    }
                                },
                                onSelect: {
                                    selectionManager.toggleAlbumSelection(album)
                                    showingOptionsForAlbumId = nil
                                },
                                onView: {
                                    showingOptionsForAlbumId = nil
                                }
                            )
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 20)
                }
                .navigationTitle("选择相册")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") {
                            // 确认选择，关闭弹窗
                            dismiss()
                        }
                        .disabled(selectionManager.selectedAlbums.isEmpty)
                    }
                }
            }
            .onAppear {
                // 每次进入相册页时清空之前的选择
                selectionManager.clearSelection()
                // 加载相册列表（已按首字母排序）
                viewModel.loadAlbums()
            }
        }
    }
}

// MARK: - 相册卡片视图
struct AlbumCardView: View {
    let album: Album
    let cardSize: CGFloat
    let cornerRadius: CGFloat
    let isSelected: Bool
    let showOptions: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    let onView: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 相册封面
            ZStack {
                // 背景图片
                if let coverImage = album.coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardSize, height: cardSize)
                        .clipped()
                } else {
                    // 占位符
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: cardSize, height: cardSize)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                }
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 40, height: 40)
                        )
                        .opacity(0.95)
                }
                
                // 选项按钮（点击相册时显示）
                if showOptions && !isSelected {
                    Color.black.opacity(0.6)
                        .frame(width: cardSize, height: cardSize)
                    
                    VStack(spacing: 15) {
                        Button(action: onSelect) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 20))
                                Text("选择")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        NavigationLink(destination: NativeAlbumPhotosView(album: album)) {
                            HStack {
                                Image(systemName: "eye")
                                    .font(.system(size: 20))
                                Text("查看")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            onView()
                        })
                    }
                }
            }
            .cornerRadius(cornerRadius)
            .onTapGesture {
                onTap()
            }
            
            // 相册名称和照片数量
            VStack(spacing: 2) {
                Text(album.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text("\(album.photosCount) 张")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(width: cardSize)
        }
    }
}

#Preview {
    NavigationStack {
        AlbumListView()
    }
}
