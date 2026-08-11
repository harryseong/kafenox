import Foundation
import KafenoxCore
import KafenoxNetworking
import OSLog
import UIKit
import UserNotifications

/// Watches coffees whose label extraction is still running on the backend.
///
/// Uploading only creates a PENDING item and hands off to the backend's
/// Step Functions pipeline, so the user is free to leave the scan screen
/// immediately. This monitor is what closes the loop afterwards: it polls the
/// status endpoint for each in-flight photo, patches the catalog when one
/// lands, and posts a local notification so the result is noticed even from
/// another screen.
///
/// Deliberately local notifications only -- no APNs. If the app is terminated
/// before extraction finishes, nothing fires; the item simply shows up as
/// "New" the next time the catalog loads and `resume(from:)` re-adopts
/// anything still in flight.
@MainActor
@Observable
public final class UploadQueueMonitor: NSObject {
    public static let shared = UploadQueueMonitor()

    public private(set) var trackedPhotoIds: Set<String> = []

    /// Set by RootView so a tapped notification can open the right coffee.
    @ObservationIgnored public var onTapPhotoId: ((String) -> Void)?

    @ObservationIgnored private weak var catalog: CatalogViewModel?
    @ObservationIgnored private let repository: any CoffeeRepository
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    /// Slower than the old blocking scan poll (1.5s over a 30s budget): this
    /// loop can run for an open-ended stretch, so it trades latency for
    /// far fewer API calls per queued photo.
    private static let pollInterval: Duration = .seconds(4)

    public init(repository: any CoffeeRepository = APIClient.shared) {
        self.repository = repository
        super.init()
    }

    public func attach(catalog: CatalogViewModel) {
        self.catalog = catalog
    }

    /// Called right after an upload succeeds, so tracking (and the
    /// background-execution window) starts before the user can leave.
    public func track(photoId: String) {
        trackedPhotoIds.insert(photoId)
        requestNotificationAuthorizationIfNeeded()
        beginBackgroundTaskIfNeeded()
        ensurePolling()
    }

    /// Re-adopts anything the catalog says is still extracting -- covers
    /// relaunches and returns from background past the grace window.
    public func resume(from coffees: [Coffee]) {
        let inFlight = coffees.filter(\.isProcessing).map(\.photoId)
        guard !inFlight.isEmpty else { return }
        trackedPhotoIds.formUnion(inFlight)
        ensurePolling()
    }

    private func ensurePolling() {
        guard pollTask == nil, !trackedPhotoIds.isEmpty else { return }
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func pollLoop() async {
        while !trackedPhotoIds.isEmpty {
            if Task.isCancelled { break }
            for photoId in trackedPhotoIds {
                let status: UploadStatus
                do {
                    status = try await repository.uploadStatus(photoId: photoId)
                } catch {
                    // Transient failure; the next tick retries.
                    Logger.uploadQueue.debug("Status poll failed for \(photoId, privacy: .public): \(error)")
                    continue
                }
                switch status.status {
                case "COMPLETE":
                    Logger.uploadQueue.info("Extraction complete for \(photoId, privacy: .public)")
                    trackedPhotoIds.remove(photoId)
                    await handleComplete(photoId: photoId)
                case "FAILED":
                    Logger.uploadQueue.error("Extraction failed for \(photoId, privacy: .public)")
                    trackedPhotoIds.remove(photoId)
                    catalog?.markStatus(photoId: photoId, status: "FAILED", errorMessage: status.errorMessage)
                    notify(
                        title: "Scan failed",
                        body: status.errorMessage ?? "Couldn't read that label.",
                        photoId: photoId
                    )
                default:
                    break  // still PENDING/PROCESSING
                }
            }
            if trackedPhotoIds.isEmpty { break }
            try? await Task.sleep(for: Self.pollInterval)
        }
        pollTask = nil
        endBackgroundTaskIfNeeded()
    }

    private func handleComplete(photoId: String) async {
        let coffee: Coffee
        do {
            coffee = try await repository.coffee(photoId: photoId)
        } catch {
            // The item is done but unfetchable right now; let the catalog's
            // next load pick it up rather than leaving a stale spinner.
            Logger.uploadQueue.error("Fetching completed coffee \(photoId, privacy: .public) failed: \(error)")
            catalog?.markStatus(photoId: photoId, status: "COMPLETE", errorMessage: nil)
            return
        }
        catalog?.upsert(coffee)
        notify(
            title: "Scan ready",
            body: "\(coffee.displayName) is ready to review.",
            photoId: photoId
        )
    }

    // MARK: Background execution

    /// Buys the poll loop the system's short background grace period, so a
    /// scan started just before backgrounding still has a chance to land.
    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskId == .invalid else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "kafenox-upload-queue") { [weak self] in
            Task { @MainActor in self?.endBackgroundTaskIfNeeded() }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }

    // MARK: Notifications

    /// Asked for only once the user has actually queued a scan, so the
    /// prompt lands with obvious context instead of at first launch.
    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func notify(title: String, body: String, photoId: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["photoId": photoId]
        let request = UNNotificationRequest(identifier: photoId, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension UploadQueueMonitor: UNUserNotificationCenterDelegate {
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even in-app: the user may be on another tab.
        completionHandler([.banner, .sound])
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let photoId = response.notification.request.content.userInfo["photoId"] as? String {
            Task { @MainActor in self.onTapPhotoId?(photoId) }
        }
        completionHandler()
    }
}
