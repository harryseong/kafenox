import Foundation

/// Mirrors the flat DynamoDB coffee item shape returned by the backend's
/// GET /coffees and GET /coffees/{photoId} endpoints.
struct Coffee: Codable, Identifiable, Hashable {
    var id: String { photoId }

    let photoId: String
    let status: String
    let errorMessage: String?
    let createdAt: String?

    var roaster: String?
    var coffeeName: String?
    var originCountry: String?
    var originRegion: String?
    var roastDate: String?
    var roastLevel: String?
    var roastType: String? = nil
    var process: String?
    var variety: String?
    var producer: String? = nil
    var flavorNotes: [String]
    var altitude: String?

    var lat: Double?
    var lng: Double?

    var rating: Int?
    var isVerified: Bool
}
