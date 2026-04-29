//
//  InkSeedApp.swift
//  InkSeed
//
//  Created by Gazza on 22. 4. 2026..
//

import SwiftUI
import UIKit

final class OrientationAppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .allButUpsideDown

    static func updateOrientationLock(_ mask: UIInterfaceOrientationMask) {
        orientationLock = mask

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}

@main
struct InkSeedApp: App {
    @UIApplicationDelegateAdaptor(OrientationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
