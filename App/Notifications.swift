import Common
import Logging
import UserNotifications
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

func requestUNAuthorizations() async {
    do {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])
        appLogger.info("granted UN permissions")
    } catch {
        appLogger.error("failed to request UN permissions", error: error)
    }
}

class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared: AppNotificationCenterDelegate = .init()

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let taskId = userInfo["task-id"] as? String,
           let uuid = UUID(uuidString: taskId) {
            #if os(iOS)
                UIApplication.shared.open(DeepLink.memory(taskID: uuid).url)
            #elseif os(macOS)
                NSWorkspace.shared.open(DeepLink.memory(taskID: uuid).url)
            #endif
        }
    }
}
