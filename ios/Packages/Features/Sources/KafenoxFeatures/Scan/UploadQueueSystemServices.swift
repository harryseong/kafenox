import Foundation
import UIKit
import UserNotifications

/// The system side-effects the upload queue reaches for, behind a protocol.
///
/// Both `UNUserNotificationCenter.current()` and `UIApplication.shared` trap
/// in a bare xctest process (there is no app bundle), so calling them
/// directly would make the queue's transition logic untestable. This keeps
/// the interesting behavior -- polling, catalog patching, cancellation --
/// verifiable without a hosted app.
@MainActor
public protocol UploadQueueSystemServices: AnyObject {
    func requestNotificationAuthorizationIfNeeded()
    func postNotification(title: String, body: String, photoId: String)
    /// Returns an opaque token to hand back to `endBackgroundTask`.
    func beginBackgroundTask(expirationHandler: @escaping @MainActor () -> Void) -> Int
    func endBackgroundTask(_ token: Int)
}

/// The real implementation, used everywhere outside tests.
@MainActor
public final class SystemUploadQueueServices: UploadQueueSystemServices {
    public init() {}

    /// Asked for only once the user has actually queued a scan, so the
    /// prompt lands with obvious context instead of at first launch.
    public func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    public func postNotification(title: String, body: String, photoId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["photoId": photoId]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: photoId, content: content, trigger: nil)
        )
    }

    /// Buys the poll loop the system's short background grace period, so a
    /// scan started just before backgrounding still has a chance to land.
    public func beginBackgroundTask(expirationHandler: @escaping @MainActor () -> Void) -> Int {
        let identifier = UIApplication.shared.beginBackgroundTask(withName: "kafenox-upload-queue") {
            Task { @MainActor in expirationHandler() }
        }
        return identifier.rawValue
    }

    public func endBackgroundTask(_ token: Int) {
        UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: token))
    }
}
