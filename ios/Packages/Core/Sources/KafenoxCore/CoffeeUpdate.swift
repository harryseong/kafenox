import Foundation

/// A partial edit to a coffee: only the fields set here are sent, so the
/// backend leaves everything else alone.
///
/// The wire format is the flat map DynamoDB stores, but building that map by
/// hand at each call site meant stringly-typed keys with no compiler check
/// against `EDITABLE_FIELDS` on the server. Keeping the shape here means a
/// typo is a build error rather than a silently ignored field.
public struct CoffeeUpdate: Sendable, Equatable {
    public var roaster: String?
    public var coffeeName: String?
    public var originCountry: String?
    public var originRegion: String?
    public var roastDate: String?
    public var roastLevel: String?
    public var process: String?
    public var variety: String?
    public var producer: String?
    public var altitude: String?
    public var flavorNotes: [String]?
    public var rating: Int?

    /// "Looks good" -- a flag, not a stored field. The backend accepts it
    /// without any accompanying edit.
    public var verified: Bool?

    /// Settings-selected Bedrock model for categorizing newly added flavor
    /// notes. Passed through on the request; never persisted on the item.
    public var model: String?

    public init(
        roaster: String? = nil,
        coffeeName: String? = nil,
        originCountry: String? = nil,
        originRegion: String? = nil,
        roastDate: String? = nil,
        roastLevel: String? = nil,
        process: String? = nil,
        variety: String? = nil,
        producer: String? = nil,
        altitude: String? = nil,
        flavorNotes: [String]? = nil,
        rating: Int? = nil,
        verified: Bool? = nil,
        model: String? = nil
    ) {
        self.roaster = roaster
        self.coffeeName = coffeeName
        self.originCountry = originCountry
        self.originRegion = originRegion
        self.roastDate = roastDate
        self.roastLevel = roastLevel
        self.process = process
        self.variety = variety
        self.producer = producer
        self.altitude = altitude
        self.flavorNotes = flavorNotes
        self.rating = rating
        self.verified = verified
        self.model = model
    }

    /// True when there is nothing to send -- `model` alone doesn't count,
    /// since it only qualifies an accompanying flavor-note edit.
    public var isEmpty: Bool {
        payload.filter { $0.key != "model" }.isEmpty
    }

    /// The flat JSON body the backend's PATCH handler expects. Keys match its
    /// `EDITABLE_FIELDS` set plus the `verified` flag.
    public var payload: [String: Sendable] {
        var fields: [String: Sendable] = [:]
        fields["roaster"] = roaster
        fields["coffeeName"] = coffeeName
        fields["originCountry"] = originCountry
        fields["originRegion"] = originRegion
        fields["roastDate"] = roastDate
        fields["roastLevel"] = roastLevel
        fields["process"] = process
        fields["variety"] = variety
        fields["producer"] = producer
        fields["altitude"] = altitude
        fields["flavorNotes"] = flavorNotes
        fields["rating"] = rating
        fields["verified"] = verified
        fields["model"] = model
        return fields
    }
}
