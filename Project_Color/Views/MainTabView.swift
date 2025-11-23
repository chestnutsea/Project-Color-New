//
//  MainTabView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/12.
//

import SwiftUI

struct MainTabView: View {
    // MARK: - State
    @State private var selectedTab: TabItem = .scanner
    
    private enum TabItem: Int, CaseIterable {
        case scanner = 0
        case album = 1
        case palette = 2
        
        var iconName: String {
            switch self {
            case .scanner: return "scanner"
            case .album: return "photo.stack"
            case .palette: return "paintpalette"
            }
        }
        
        var title: String {
            switch self {
            case .scanner: return "扫描"
            case .album: return "相册"
            case .palette: return "工具"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(TabItem.scanner.title, systemImage: TabItem.scanner.iconName)
                }
                .tag(TabItem.scanner)
            
            AnalysisLibraryView()
                .tabItem {
                    Label(TabItem.album.title, systemImage: TabItem.album.iconName)
                }
                .tag(TabItem.album)
            
            KitView()
                .tabItem {
                    Label(TabItem.palette.title, systemImage: TabItem.palette.iconName)
                }
                .tag(TabItem.palette)
        }
        .tint(.black)  // 设置选中颜色为黑色
        .onAppear {
            // 设置 TabBar 的外观
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
