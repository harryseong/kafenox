import Foundation

/// Everything the app can ask of the coffee backend, expressed in domain
/// types. Features depend on this protocol rather than the concrete API
/// client, so tests substitute a hand-written stub and the transport stays
/// replaceable.
public protocol CoffeeRepository: Sendable {
    func listCoffees() async throws -> [Coffee]
    func coffee(photoId: String) async throws -> Coffee
    func updateCoffee(photoId: String, _ update: CoffeeUpdate) async throws -> Coffee
    /// "Looks good" -- confirms an extracted coffee as-is, without edits.
    func verifyCoffee(photoId: String) async throws -> Coffee
    func deleteCoffee(photoId: String) async throws

    /// Reserves a photo id and returns the presigned URL to upload the JPEG to.
    func initiateUpload(models: [String: String]) async throws -> UploadTicket
    func uploadPhoto(_ imageData: Data, to uploadUrl: URL) async throws
    func uploadStatus(photoId: String) async throws -> UploadStatus

    func askInsights(question: String, history: [ChatTurn], model: String?) async throws -> String
}

public struct UploadTicket: Decodable, Sendable {
    public let photoId: String
    public let uploadUrl: URL

    public init(photoId: String, uploadUrl: URL) {
        self.photoId = photoId
        self.uploadUrl = uploadUrl
    }
}

public struct UploadStatus: Decodable, Sendable {
    public let photoId: String
    public let status: String
    public let errorMessage: String?

    public init(photoId: String, status: String, errorMessage: String? = nil) {
        self.photoId = photoId
        self.status = status
        self.errorMessage = errorMessage
    }
}

public struct ChatTurn: Sendable, Equatable {
    public let role: String
    public let text: String

    public init(role: String, text: String) {
        self.role = role
        self.text = text
    }
}
