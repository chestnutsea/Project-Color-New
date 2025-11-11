//
//  MainTabView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/12.
//

import SwiftUI

struct MainTabView: View {
    // MARK: - Layout Constants
    private let tabBarHeight: CGFloat = 60
    private let tabBarIconSize: CGFloat = 24
    private let tabBarPadding: CGFloat = 20
    
    // MARK: - State
    @State private var selectedTab: TabItem = .scanner
    
    private enum TabItem: Int, CaseIterable {
        case scanner = 0
        case palette = 1
        
        var iconName: String {
            switch self {
            case .scanner: return "scanner"
            case .palette: return "paintpalette"
            }
        }
        
        var selectedIconName: String {
            switch self {
            case .scanner: return "scanner.fill"
            case .palette: return "paintpalette.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域（支持滑动）
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(TabItem.scanner)
                
                KitView()
                    .tag(TabItem.palette)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // 自定义 Tab Bar（固定在底部，覆盖在内容上方）
            VStack(spacing: 0) {
                Divider()
                customTabBar
            }
            .frame(height: tabBarHeight + 1) // +1 for divider
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.selectedIconName : tab.iconName)
                            .font(.system(size: tabBarIconSize, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: tabBarHeight)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, tabBarPadding)
        .background(Color(.systemBackground))
    }
}

#Preview {
    MainTabView()
}
