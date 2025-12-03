//
//  TabBarVisibility.swift
//  Project_Color
//
//  工具类：控制 TabBar 的显示/隐藏（无动画延迟）
//

import SwiftUI
import UIKit

// MARK: - TabBar 可见性控制器

struct TabBarVisibilityModifier: ViewModifier {
    let isHidden: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setTabBarHidden(isHidden)
            }
            .onDisappear {
                // 返回时立即显示 TabBar
                if isHidden {
                    setTabBarHidden(false)
                }
            }
    }
    
    private func setTabBarHidden(_ hidden: Bool) {
        // 在主线程上执行，确保 UI 更新
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                return
            }
            
            // 遍历视图层级找到 UITabBarController
            if let tabBarController = findTabBarController(in: window.rootViewController) {
                tabBarController.tabBar.isHidden = hidden
            }
        }
    }
    
    private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        guard let vc = viewController else { return nil }
        
        // 如果当前就是 UITabBarController，直接返回
        if let tabBarController = vc as? UITabBarController {
            return tabBarController
        }
        
        // 检查子视图控制器
        for child in vc.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }
        
        // 检查 presented 的视图控制器
        if let presented = vc.presentedViewController {
            if let tabBarController = findTabBarController(in: presented) {
                return tabBarController
            }
        }
        
        return nil
    }
}

extension View {
    /// 隐藏 TabBar（进入时隐藏，返回时立即恢复）
    func hideTabBar(_ hide: Bool = true) -> some View {
        modifier(TabBarVisibilityModifier(isHidden: hide))
    }
}

