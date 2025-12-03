//
//  TabBarVisibility.swift
//  Project_Color
//
//  工具类：控制 TabBar 的显示/隐藏（无动画延迟）
//

import SwiftUI
import UIKit

// MARK: - TabBar 可见性控制器（支持嵌套隐藏）

private final class TabBarVisibilityController {
    static let shared = TabBarVisibilityController()
    
    private var hideRequests: Int = 0   // 允许多个页面同时请求隐藏，避免中途闪现
    private var lastHiddenState: Bool = false
    
    func requestHide() {
        hideRequests += 1
        updateTabBarVisibility()
    }
    
    func cancelHide() {
        hideRequests = max(0, hideRequests - 1)
        updateTabBarVisibility()
    }
    
    func showIfNeeded() {
        // 将计数清零，确保显示
        hideRequests = 0
        updateTabBarVisibility()
    }
    
    private func updateTabBarVisibility() {
        let shouldHide = hideRequests > 0
        guard shouldHide != lastHiddenState else { return }
        lastHiddenState = shouldHide
        
        // 在主线程上执行，确保 UI 更新
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            if let tabBarController = Self.findTabBarController(in: window.rootViewController) {
                tabBarController.tabBar.isHidden = shouldHide
            }
        }
    }
    
    private static func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        guard let vc = viewController else { return nil }
        
        if let tabBarController = vc as? UITabBarController {
            return tabBarController
        }
        
        for child in vc.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        
        if let presented = vc.presentedViewController {
            if let tabBarController = findTabBarController(in: presented) {
                return tabBarController
            }
        }
        
        return nil
    }
}

struct TabBarVisibilityModifier: ViewModifier {
    let isHidden: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if isHidden {
                    TabBarVisibilityController.shared.requestHide()
                } else {
                    TabBarVisibilityController.shared.showIfNeeded()
                }
            }
            .onDisappear {
                if isHidden {
                    TabBarVisibilityController.shared.cancelHide()
                }
            }
    }
}

extension View {
    /// 隐藏 TabBar（进入时隐藏，返回时立即恢复）
    func hideTabBar(_ hide: Bool = true) -> some View {
        modifier(TabBarVisibilityModifier(isHidden: hide))
    }
}
