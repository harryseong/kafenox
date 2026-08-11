import Foundation

/// Presentation-independent derivations from a coffee's fields. The visual
/// counterparts (swatch color) live in the design system, so this file stays
/// free of SwiftUI and usable from tests and non-UI code.
extension Coffee {
    public var initials: String {
        let source = roaster ?? coffeeName ?? "?"
        let words = source.split(separator: " ").filter { !$0.isEmpty }
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// Maps the backend's 6-value roastLevel enum down to the prototype's
    /// 3-bucket filter chips (All/Light/Medium/Dark).
    public var roastGroup: String {
        switch roastLevel {
        case "light", "medium-light": return "Light"
        case "medium": return "Medium"
        case "medium-dark", "dark": return "Dark"
        default: return "Medium"
        }
    }

    /// 1-5 scale used for the Detail screen's roast-level progress bar.
    public var roastLevelOrdinal: Int {
        switch roastLevel {
        case "light": return 1
        case "medium-light": return 2
        case "medium": return 3
        case "medium-dark": return 4
        case "dark": return 5
        default: return 3
        }
    }

    public var originLabel: String {
        [originRegion, originCountry].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Extraction-status helpers. Uploads are queued and extracted in the
/// background, so the catalog shows items in every state -- these name the
/// states the UI actually branches on.
extension Coffee {
    public var isProcessing: Bool { status == "PENDING" || status == "PROCESSING" }
    public var isFailedExtraction: Bool { status == "FAILED" }
    public var isCompleteExtraction: Bool { status == "COMPLETE" }
    /// Extracted but not yet confirmed by the user -- drives the "New" badge.
    public var isNew: Bool { isCompleteExtraction && !isVerified }

    /// Name for notification/placeholder copy, matching the "Untitled"
    /// fallback used across the detail and edit screens.
    public var displayName: String { coffeeName ?? roaster ?? "Untitled" }
}
