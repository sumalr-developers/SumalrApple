#if os(macOS)
    import AppKit
    import Foundation
    import Logging
    import SwiftUI
    internal import Combine
    import Common
    import UserNotifications

    @Observable
    class NSApp: NSObject, NSApplicationDelegate {
        private var _deviceToken: Data?
        var deviceToken: Data? {
            _deviceToken
        }

        func applicationDidFinishLaunching(_ notification: Notification) {
            NSApplication.shared.registerForRemoteNotifications()
            AppNotificationCenterDelegate.shared.register()
            Task {
                await requestUNAuthorizations()
            }
        }

        func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            _deviceToken = deviceToken
            setDeviceToken(deviceToken, to: .appGroup)
        }

        func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
            appLogger.error("failed to register for remote notifications", error: error)
            DispatchQueue.main.schedule(
                after: DispatchQueue.SchedulerTimeType(.now().advanced(by: .seconds(10))),
                tolerance: .seconds(1)
            ) {
                NSApplication.shared.registerForRemoteNotifications()
            }
        }
    }
#endif
