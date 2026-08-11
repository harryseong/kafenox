import Foundation

/// Mirrors the flat DynamoDB coffee item shape returned by the backend's
/// GET /coffees and GET /coffees/{photoId} endpoints.
public struct Coffee: Codable, Identifiable, Hashable, Sendable {
    public var id: String { photoId }

    public let photoId: String
    /// Extraction-pipeline state: PENDING -> PROCESSING -> COMPLETE/FAILED.
    /// Mutable so the upload-queue monitor can patch a single tracked item
    /// in place instead of reloading the whole catalog on every poll tick.
    public var status: String
    public var errorMessage: String?
    public let createdAt: String?

    public var roaster: String?
    public var coffeeName: String?
    public var originCountry: String?
    public var originRegion: String?
    public var roastDate: String?
    public var roastLevel: String?
    public var roastType: String?
    public var process: String?
    public var variety: String?
    public var producer: String?
    public var flavorNotes: [String]
    /// note -> flavor family name, categorized server-side by Claude at
    /// extraction/edit time. Absent for coffees that predate categorization;
    /// the client falls back to `FlavorFamily.of(_:)`.
    public var flavorFamilies: [String: String]?
    public var altitude: String?

    public var lat: Double?
    public var lng: Double?

    public var rating: Int?
    public var isVerified: Bool

    public init(
        photoId: String,
        status: String,
        errorMessage: String? = nil,
        createdAt: String? = nil,
        roaster: String? = nil,
        coffeeName: String? = nil,
        originCountry: String? = nil,
        originRegion: String? = nil,
        roastDate: String? = nil,
        roastLevel: String? = nil,
        roastType: String? = nil,
        process: String? = nil,
        variety: String? = nil,
        producer: String? = nil,
        flavorNotes: [String] = [],
        flavorFamilies: [String: String]? = nil,
        altitude: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        rating: Int? = nil,
        isVerified: Bool = false
    ) {
        self.photoId = photoId
        self.status = status
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.roaster = roaster
        self.coffeeName = coffeeName
        self.originCountry = originCountry
        self.originRegion = originRegion
        self.roastDate = roastDate
        self.roastLevel = roastLevel
        self.roastType = roastType
        self.process = process
        self.variety = variety
        self.producer = producer
        self.flavorNotes = flavorNotes
        self.flavorFamilies = flavorFamilies
        self.altitude = altitude
        self.lat = lat
        self.lng = lng
        self.rating = rating
        self.isVerified = isVerified
    }
}
