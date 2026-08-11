import Foundation
import KafenoxCore
import KafenoxNetworking
import OSLog
import UIKit

public enum ScanStep: Sendable {
    case capturing
    case uploading
    case queued
    case failed(message: String)
}

/// Owns capture -> upload -> queued. Extraction itself runs on the backend
/// (S3 event -> Step Functions -> Bedrock), which can take a while, so this
/// no longer waits for it: once the photo is uploaded the item is handed to
/// UploadQueueMonitor and the user is returned to the catalog, where the row
/// shows "Processing" until the result lands. Review happens later from the
/// detail screen, not inline here.
@Observable
public final class ScanViewModel {
    public var step: ScanStep = .capturing
    public var capturedImage: UIImage?
    public var photoId: String?

    private let repository: any CoffeeRepository

    public init(repository: any CoffeeRepository = APIClient.shared) {
        self.repository = repository
    }

    private var uploadTask: Task<Void, Never>?

    /// A short grace period after upload to catch failures the pipeline
    /// reports immediately (an unreadable image, say) while the user is still
    /// looking at the scan screen. Anything slower is the queue's problem.
    private static let earlyFailureDelay: Duration = .milliseconds(1500)

    public func reset() {
        cancelUpload()
        step = .capturing
        capturedImage = nil
        photoId = nil
    }

    public func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    @MainActor
    public func didCapture(_ image: UIImage) {
        capturedImage = image
        step = .uploading
        uploadTask = Task { [weak self] in
            await self?.uploadAndQueue(image: image)
        }
    }

    @MainActor
    private func uploadAndQueue(image: UIImage) async {
        do {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                step = .failed(message: "Couldn't process that photo.")
                return
            }
            let models = [
                "scan": SettingsStore.shared.model(for: .scan).rawValue,
                "notes": SettingsStore.shared.model(for: .notes).rawValue,
            ]
            let upload = try await repository.initiateUpload(models: models)
            photoId = upload.photoId
            try await repository.uploadPhoto(jpeg, to: upload.uploadUrl)

            try await Task.sleep(for: Self.earlyFailureDelay)
            if Task.isCancelled { return }
            if let status = try? await repository.uploadStatus(photoId: upload.photoId),
                status.status == "FAILED"
            {
                step = .failed(message: status.errorMessage ?? "Couldn't read that label.")
                return
            }

            UploadQueueMonitor.shared.track(photoId: upload.photoId)
            step = .queued
        } catch is CancellationError {
            // view was dismissed mid-flow, nothing to surface
        } catch let error as APIError {
            // Surface the specific failure so config issues (e.g. a 403 from a
            // missing API key) are diagnosable on-device rather than hidden
            // behind a generic message.
            Logger.scan.error("Upload failed: \(error.diagnosticDescription, privacy: .public)")
            switch error {
            case .server, .decoding:
                step = .failed(message: error.errorDescription ?? "Upload failed.")
            }
        } catch {
            Logger.scan.error("Upload failed: \(error)")
            step = .failed(message: "Something went wrong uploading that photo.")
        }
    }

    @MainActor
    public func retake() {
        cancelUpload()
        step = .capturing
        capturedImage = nil
        photoId = nil
    }
}
