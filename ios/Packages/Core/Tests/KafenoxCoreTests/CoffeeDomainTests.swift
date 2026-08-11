import Testing

@testable import KafenoxCore

@Suite("Coffee extraction status")
struct CoffeeStatusTests {
    private func coffee(status: String, isVerified: Bool = false) -> Coffee {
        Coffee(photoId: "id", status: status, isVerified: isVerified)
    }

    @Test("Queued and in-flight scans both read as processing", arguments: ["PENDING", "PROCESSING"])
    func processingStates(_ status: String) {
        let item = coffee(status: status)
        #expect(item.isProcessing)
        #expect(!item.isCompleteExtraction)
        #expect(!item.isNew)
    }

    @Test("A failed scan is neither processing nor new")
    func failedState() {
        let item = coffee(status: "FAILED")
        #expect(item.isFailedExtraction)
        #expect(!item.isProcessing)
        #expect(!item.isNew)
    }

    @Test("Extracted-but-unverified is what drives the New badge")
    func newState() {
        #expect(coffee(status: "COMPLETE", isVerified: false).isNew)
    }

    @Test("Confirming an extraction clears New")
    func verifiedIsNotNew() {
        #expect(!coffee(status: "COMPLETE", isVerified: true).isNew)
    }

    @Test("An in-flight scan is never New, even though it is unverified")
    func processingIsNotNew() {
        #expect(!coffee(status: "PENDING", isVerified: false).isNew)
    }
}

@Suite("Coffee display helpers")
struct CoffeeDisplayTests {
    @Test(
        "Roast levels collapse to the three filter buckets",
        arguments: [
            ("light", "Light"), ("medium-light", "Light"),
            ("medium", "Medium"),
            ("medium-dark", "Dark"), ("dark", "Dark"),
        ])
    func roastGroup(_ level: String, _ expected: String) {
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: level).roastGroup == expected)
    }

    @Test("An unknown or missing roast level falls back to Medium")
    func roastGroupFallback() {
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: nil).roastGroup == "Medium")
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: "charred").roastGroup == "Medium")
    }

    @Test("Roast ordinal spans the 1-5 progress bar")
    func roastOrdinal() {
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: "light").roastLevelOrdinal == 1)
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: "dark").roastLevelOrdinal == 5)
        #expect(Coffee(photoId: "id", status: "COMPLETE", roastLevel: nil).roastLevelOrdinal == 3)
    }

    @Test("Origin label joins region and country, skipping missing parts")
    func originLabel() {
        #expect(
            Coffee(photoId: "1", status: "COMPLETE", originCountry: "Kenya", originRegion: "Nyeri").originLabel
                == "Nyeri, Kenya")
        #expect(Coffee(photoId: "2", status: "COMPLETE", originCountry: "Kenya").originLabel == "Kenya")
        #expect(Coffee(photoId: "3", status: "COMPLETE").originLabel.isEmpty)
    }

    @Test("Display name prefers the coffee name, then roaster, then a placeholder")
    func displayName() {
        #expect(
            Coffee(photoId: "1", status: "COMPLETE", roaster: "Ridgeline", coffeeName: "Konga").displayName == "Konga")
        #expect(Coffee(photoId: "2", status: "COMPLETE", roaster: "Ridgeline").displayName == "Ridgeline")
        // A just-uploaded coffee has neither field yet.
        #expect(Coffee(photoId: "3", status: "PENDING").displayName == "Untitled")
    }

    @Test("Initials take the first letter of up to two words")
    func initials() {
        #expect(Coffee(photoId: "1", status: "COMPLETE", roaster: "North Fell Coffee").initials == "NF")
        #expect(Coffee(photoId: "2", status: "COMPLETE").initials == "?")
    }
}

@Suite("Flavor family lookup")
struct FlavorFamilyTests {
    @Test("Known notes map to their family")
    func knownNote() {
        #expect(FlavorFamily.of("Bergamot").name == "Floral & Tea")
        #expect(FlavorFamily.of("Caramel").name == "Sweet")
    }

    @Test("Unrecognized notes fall into Other rather than dropping out")
    func unknownNote() {
        #expect(FlavorFamily.of("Unobtainium").name == FlavorFamily.other.name)
    }

    @Test("Backend-assigned family names resolve, including Other")
    func lookupByName() {
        #expect(FlavorFamily.named("Sweet")?.name == "Sweet")
        #expect(FlavorFamily.named("Other")?.name == "Other")
        #expect(FlavorFamily.named("Nonexistent") == nil)
    }

    @Test("No note is claimed by two families")
    func noDuplicateNotes() throws {
        let all = FlavorFamily.all.flatMap(\.notes)
        #expect(all.count == Set(all).count)
    }
}
