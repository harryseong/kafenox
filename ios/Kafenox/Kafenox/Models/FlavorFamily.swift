import SwiftUI

/// Groups the free-text flavor notes into the prototype's five colored
/// families (plus an "Other" catch-all) so the Insights screen can chart them.
/// The note→family mapping mirrors the Claude Design prototype's `FAMILIES`
/// table; anything the backend extracts that isn't listed falls into `.other`.
struct FlavorFamily: Identifiable, Hashable {
    let name: String
    let hex: UInt32
    let notes: [String]

    var id: String { name }
    var color: Color { Color(hex: hex) }

    static let all: [FlavorFamily] = [
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

    static let other = FlavorFamily(name: "Other", hex: 0x8a7c6c, notes: [])

    private static let lookup: [String: FlavorFamily] = {
        var map: [String: FlavorFamily] = [:]
        for family in all {
            for note in family.notes { map[note] = family }
        }
        return map
    }()

    static func of(_ note: String) -> FlavorFamily {
        lookup[note] ?? other
    }
}

/// How often a single flavor note appears across the collection.
struct FlavorNoteStat: Identifiable {
    let note: String
    let count: Int
    let family: FlavorFamily
    var id: String { note }
}

/// Aggregate note count for a whole flavor family.
struct FlavorFamilyStat: Identifiable {
    let family: FlavorFamily
    let total: Int
    var id: String { family.name }
}
