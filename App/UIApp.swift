#if os(iOS)
    import AsyncAlgorithms
    import Common
    import Foundation
    import Logging
    import UIKit
    internal import Combine
    internal import ConcurrencyExtras

    @Observable
    class UIApp: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
        var _deviceToken: Data?
        var deviceToken: Data? {
            _deviceToken
        }

        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            UIApplication.shared.registerForRemoteNotifications()
            AppNotificationCenterDelegate.shared.register()
            Task {
                await requestUNAuthorizations()
            }
            return true
        }

        func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            _deviceToken = deviceToken
            setDeviceToken(deviceToken, to: .appGroup)
        }

        func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
            appLogger.error("failed to register for remote notifications", error: error)
            DispatchQueue.main.schedule(
                after: DispatchQueue.SchedulerTimeType(.now().advanced(by: .seconds(10))),
                tolerance: .seconds(1)
            ) {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
#endif
