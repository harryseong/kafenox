import Foundation

@testable import KafenoxFeatures

/// Records what the monitor asked the system to do, instead of touching
/// UNUserNotificationCenter / UIApplication (which trap without an app bundle).
@MainActor
final class SpyUploadQueueServices: UploadQueueSystemServices {
    struct Posted: Equatable {
        let title: String
        let body: String
        let photoId: String
    }

    private(set) var posted: [Posted] = []
    private(set) var authorizationRequests = 0
    private(set) var backgroundTasksBegun = 0
    private(set) var backgroundTasksEnded = 0

    private var nextToken = 1

    func requestNotificationAuthorizationIfNeeded() {
        authorizationRequests += 1
    }

    func postNotification(title: String, body: String, photoId: String) {
        posted.append(Posted(title: title, body: body, photoId: photoId))
    }

    func beginBackgroundTask(expirationHandler: @escaping @MainActor () -> Void) -> Int {
        backgroundTasksBegun += 1
        defer { nextToken += 1 }
        return nextToken
    }

    func endBackgroundTask(_ token: Int) {
        backgroundTasksEnded += 1
    }
}
