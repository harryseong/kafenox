import Foundation

/// Groups the free-text flavor notes into the prototype's five colored
/// families (plus an "Other" catch-all) so the Insights screen can chart them.
/// The note→family mapping mirrors the Claude Design prototype's `FAMILIES`
/// table; anything the backend extracts that isn't listed falls into `.other`.
public struct FlavorFamily: Identifiable, Hashable, Sendable {
    public let name: String
    /// 0xRRGGBB chart color; DesignSystem turns this into a `Color`.
    public let hex: UInt32
    public let notes: [String]

    public var id: String { name }

    public static let all: [FlavorFamily] = [
        FlavorFamily(name: "Fruity", hex: 0xc2553e, notes: [
            "Peach", "Blackcurrant", "Red Apple", "Orange", "Apricot", "Cherry",
            "Plum", "Tropical", "Red Grape", "Stone Fruit", "Lime", "Citrus",
            "Dried Fruit", "Wine", "Tomato",
        ]),
        FlavorFamily(name: "Floral & Tea", hex: 0x8a6fb0, notes: [
            "Bergamot", "Black Tea", "Jasmine", "Florals", "Floral",
        ]),
        FlavorFamily(name: "Sweet", hex: 0xc2913e, notes: [
            "Cane Sugar", "Caramel", "Honey", "Brown Sugar", "Toffee", "Maple",
        ]),
        FlavorFamily(name: "Nutty & Cocoa", hex: 0x8a6b3e, notes: [
            "Cocoa", "Almond", "Dark Chocolate", "Milk Chocolate", "Dark Cocoa",
            "Peanut", "Hazelnut", "Walnut",
        ]),
        FlavorFamily(name: "Spice & Wood", hex: 0x5e7a4a, notes: [
            "Cedar", "Tobacco", "Spiced",
        ]),
    ]

    public static let other = FlavorFamily(name: "Other", hex: 0x8a7c6c, notes: [])

    public init(name: String, hex: UInt32, notes: [String]) {
        self.name = name
        self.hex = hex
        self.notes = notes
    }

    private static let lookup: [String: FlavorFamily] = {
        var map: [String: FlavorFamily] = [:]
        for family in all {
            for note in family.notes { map[note] = family }
        }
        return map
    }()

    public static func of(_ note: String) -> FlavorFamily {
        lookup[note] ?? other
    }

    private static let byName: [String: FlavorFamily] = {
        var map: [String: FlavorFamily] = [FlavorFamily.other.name: .other]
        for family in all { map[family.name] = family }
        return map
    }()

    /// Family by its backend-assigned name (see Coffee.flavorFamilies).
    public static func named(_ name: String) -> FlavorFamily? {
        byName[name]
    }
}

/// How often a single flavor note appears across the collection.
public struct FlavorNoteStat: Identifiable, Sendable {
    public let note: String
    public let count: Int
    public let family: FlavorFamily
    public var id: String { note }

    public init(note: String, count: Int, family: FlavorFamily) {
        self.note = note
        self.count = count
        self.family = family
    }
}

/// Aggregate note count for a whole flavor family.
public struct FlavorFamilyStat: Identifiable, Sendable {
    public let family: FlavorFamily
    public let total: Int
    public var id: String { family.name }

    public init(family: FlavorFamily, total: Int) {
        self.family = family
        self.total = total
    }
}
