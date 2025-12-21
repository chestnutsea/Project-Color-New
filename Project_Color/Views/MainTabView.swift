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
    
    init() {
        // 设置 TabBar 的外观：iOS 16+ 使用半透明毛玻璃，其它版本保持纯透明
        let appearance = UITabBarAppearance()
        
        if #available(iOS 16.0, *) {
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
            appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.45)
        } else {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundEffect = nil
        }
        
        appearance.shadowColor = .clear
        appearance.shadowImage = nil
        appearance.backgroundImage = nil
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().barTintColor = .clear
    }
    
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
            case .scanner: return L10n.Tab.scanner.localized
            case .album: return L10n.Tab.album.localized
            case .emerge: return L10n.Tab.emerge.localized
            case .mine: return L10n.Tab.mine.localized
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
        // ✅ 设置 TabBar 的强调色为黑色（亮色模式）/ 白色（暗黑模式）
        .tint(Color.primary)
        // iOS 16+ 兼容：条件编译处理 toolbar(for:)
        .apply { view in
            if #available(iOS 16.0, *) {
                view.toolbar(tabBarVisibility.isHidden ? .hidden : .visible, for: .tabBar)
            } else {
                view  // iOS 16 不支持 .toolbar(for:)，TabBar 始终显示
            }
        }
        .environmentObject(tabBarVisibility)
    }
}

#Preview {
    MainTabView()
}
