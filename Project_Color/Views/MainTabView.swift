//
//  MainTabView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/12.
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Tab Bar 可见性控制

/// 用于控制 Tab Bar 显示/隐藏的环境变量
class TabBarVisibility: ObservableObject {
    @Published var isHidden: Bool = false
}

struct MainTabView: View {
    // MARK: - State
    @State private var selectedTab: TabItem = .scanner
    @StateObject private var tabBarVisibility = TabBarVisibility()
    
    private enum TabItem: Int, CaseIterable {
        case scanner = 0
        case album = 1
        case emerge = 2
        case mine = 3
        
        var iconName: String {
            switch self {
            case .scanner: return "camera.aperture"
            case .album: return "photo.stack"
            case .emerge: return "camera.filters"
            case .mine: return "person.crop.square.badge.camera"
            }
        }
        
        var title: String {
            switch self {
            case .scanner: return "扫描"
            case .album: return "相册"
            case .emerge: return "显影"
            case .mine: return "我的"
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
            
            EmergeView()
                .tabItem {
                    Label(TabItem.emerge.title, systemImage: TabItem.emerge.iconName)
                }
                .tag(TabItem.emerge)
            
            KitView()
                .tabItem {
                    Label(TabItem.mine.title, systemImage: TabItem.mine.iconName)
                }
                .tag(TabItem.mine)
        }
        .tint(.black)  // 设置选中颜色为黑色
        .toolbar(tabBarVisibility.isHidden ? .hidden : .visible, for: .tabBar)
        .environmentObject(tabBarVisibility)
        .onAppear {
            // 设置 TabBar 的外观：透明背景
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            
            // 保持 TabBar 图标的正常显示
            appearance.shadowColor = .clear  // 移除阴影
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
