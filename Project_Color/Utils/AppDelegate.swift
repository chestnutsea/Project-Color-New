//
//  AppDelegate.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/12/13.
//

#if canImport(UIKit)
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        // 根据设备类型返回支持的方向
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 支持所有方向（包括倒置）
            return .all
        } else {
            // iPhone: 不支持倒置方向
            return [.portrait, .landscapeLeft, .landscapeRight]
        }
    }
}
#endif


