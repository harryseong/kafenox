import Foundation
import UIKit

enum ScanStep {
    case capturing
    case scanning
    case review
    case failed(message: String)
}

/// Owns the capture -> upload -> poll -> review flow. The prototype's
/// "Scanning" screen reveals 6 canned fields on a fixed timer; the real
/// backend gives no partial-extraction signal, so this shows one
/// indeterminate "reading label" state for the whole poll instead of faking
/// a staggered reveal.
@Observable
final class ScanViewModel {
    var step: ScanStep = .capturing
    var capturedImage: UIImage?
    var photoId: String?
    var original: Coffee?

    // Editable draft fields for the Review screen, matching the prototype's
    // Review inputs exactly (roastDate/altitude/flavorNotes aren't editable
    // there even though the backend's PATCH allows it).
    var draftRoaster = ""
    var draftName = ""
    var draftCountry = ""
    var draftRegion = ""
    var draftProcess = ""
    var draftVariety = ""
    var draftProducer = ""

    private var pollTask: Task<Void, Never>?

    private static let pollInterval: Duration = .milliseconds(1500)
    private static let pollTimeout: Duration = .seconds(30)

    func reset() {
        cancelPolling()
        step = .capturing
        capturedImage = nil
        photoId = nil
        original = nil
    }

    func cancelPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    @MainActor
    func didCapture(_ image: UIImage) {
        capturedImage = image
        step = .scanning
        pollTask = Task { [weak self] in
            await self?.uploadAndPoll(image: image)
        }
    }

    @MainActor
    private func uploadAndPoll(image: UIImage) async {
        do {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                step = .failed(message: "Couldn't process that photo.")
                return
            }
            let upload = try await APIClient.shared.initiateUpload()
            photoId = upload.photoId
            try await APIClient.shared.uploadPhoto(jpeg, to: upload.uploadUrl)

            let deadline = ContinuousClock.now + Self.pollTimeout
            while ContinuousClock.now < deadline {
                if Task.isCancelled { return }
                let status = try await APIClient.shared.getUploadStatus(photoId: upload.photoId)
                if status.status == "COMPLETE" {
                    let coffee = try await APIClient.shared.getCoffee(photoId: upload.photoId)
                    populateDraft(from: coffee)
                    step = .review
                    return
                } else if status.status == "FAILED" {
                    step = .failed(message: status.errorMessage ?? "Couldn't read that label.")
                    return
                }
                try await Task.sleep(for: Self.pollInterval)
            }
            step = .failed(message: "That's taking longer than expected.")
        } catch is CancellationError {
            // view was dismissed mid-flow, nothing to surface
        } catch let error as APIError {
            // Surface the specific failure so config issues (e.g. a 403 from a
            // missing API key) are diagnosable on-device rather than hidden
            // behind a generic message.
            print("Scan upload failed: \(error)")
            switch error {
            case .server(let statusCode):
                step = .failed(message: "Upload failed (HTTP \(statusCode)).")
            case .decoding:
                step = .failed(message: "Couldn't read the server's response.")
            }
        } catch {
            print("Scan upload failed: \(error)")
            step = .failed(message: "Something went wrong uploading that photo. (\(error.localizedDescription))")
        }
    }

    private func populateDraft(from coffee: Coffee) {
        original = coffee
        draftRoaster = coffee.roaster ?? ""
        draftName = coffee.coffeeName ?? ""
        draftCountry = coffee.originCountry ?? ""
        draftRegion = coffee.originRegion ?? ""
        draftProcess = coffee.process ?? ""
        draftVariety = coffee.variety ?? ""
        draftProducer = coffee.producer ?? ""
    }

    @MainActor
    func retake() {
        cancelPolling()
        step = .capturing
        capturedImage = nil
        photoId = nil
        original = nil
    }

    /// Only PATCHes fields the user actually changed, matching the backend's
    /// isVerified semantics (any non-rating edit marks it human-verified).
    @MainActor
    func addToCollection() async throws -> Coffee {
        guard let photoId, let original else {
            throw URLError(.unknown)
        }
        var changed: [String: Any] = [:]
        if draftRoaster != (original.roaster ?? "") { changed["roaster"] = draftRoaster }
        if draftName != (original.coffeeName ?? "") { changed["coffeeName"] = draftName }
        if draftCountry != (original.originCountry ?? "") { changed["originCountry"] = draftCountry }
        if draftRegion != (original.originRegion ?? "") { changed["originRegion"] = draftRegion }
        if draftProcess != (original.process ?? "") { changed["process"] = draftProcess }
        if draftVariety != (original.variety ?? "") { changed["variety"] = draftVariety }
        if draftProducer != (original.producer ?? "") { changed["producer"] = draftProducer }

        guard !changed.isEmpty else { return original }
        return try await APIClient.shared.updateCoffee(photoId: photoId, fields: changed)
    }
}
