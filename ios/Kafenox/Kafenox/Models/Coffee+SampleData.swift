import Foundation

#if DEBUG
/// Bundled sample data for UI testing without a deployed backend -- only
/// compiled into Debug builds at all, so it can never end up in a
/// Release/App Store archive even by accident. See APIConfig.useMockData.
extension Coffee {
    static let sampleData: [Coffee] = [
        Coffee(
            photoId: "sample-konga", status: "COMPLETE", errorMessage: nil, createdAt: "2025-03-12T09:00:00Z",
            roaster: "Ridgeline Roasters", coffeeName: "Konga", originCountry: "Ethiopia", originRegion: "Yirgacheffe",
            roastDate: "2025-03", roastLevel: "light", process: "Washed", variety: "Heirloom",
            flavorNotes: ["Bergamot", "Peach", "Black Tea"], altitude: "1900-2100 masl",
            lat: 6.8, lng: 38.2, rating: 9, isVerified: true
        ),
        Coffee(
            photoId: "sample-nyeri", status: "COMPLETE", errorMessage: nil, createdAt: "2025-02-20T09:00:00Z",
            roaster: "North Fell Coffee", coffeeName: "Nyeri AA", originCountry: "Kenya", originRegion: "Nyeri",
            roastDate: "2025-02", roastLevel: "light", process: "Washed", variety: "SL28",
            flavorNotes: ["Blackcurrant", "Tomato", "Cane Sugar"], altitude: "1700 masl",
            lat: -0.4, lng: 37.0, rating: 8, isVerified: true
        ),
        Coffee(
            photoId: "sample-esperanza", status: "COMPLETE", errorMessage: nil, createdAt: "2025-01-15T09:00:00Z",
            roaster: "Ember & Oak", coffeeName: "La Esperanza", originCountry: "Colombia", originRegion: "Huila",
            roastDate: "2025-01", roastLevel: "medium", process: "Washed", variety: "Caturra",
            flavorNotes: ["Caramel", "Red Apple", "Cocoa"], altitude: "1750 masl",
            lat: 2.5, lng: -75.5, rating: 8, isVerified: false
        ),
        Coffee(
            photoId: "sample-antigua", status: "COMPLETE", errorMessage: nil, createdAt: "2024-12-05T09:00:00Z",
            roaster: "Tidewater Coffee Co.", coffeeName: "Antigua", originCountry: "Guatemala", originRegion: "Antigua",
            roastDate: "2024-12", roastLevel: "medium", process: "Washed", variety: "Bourbon",
            flavorNotes: ["Milk Chocolate", "Orange", "Almond"], altitude: nil,
            lat: 14.5, lng: -90.7, rating: nil, isVerified: false
        ),
        Coffee(
            photoId: "sample-tarrazu", status: "COMPLETE", errorMessage: nil, createdAt: "2025-02-02T09:00:00Z",
            roaster: "Meridian Roastworks", coffeeName: "Tarrazu", originCountry: "Costa Rica", originRegion: "Tarrazu",
            roastDate: "2025-02", roastLevel: "medium-light", process: "Honey", variety: "Catuai",
            flavorNotes: ["Honey", "Apricot", "Brown Sugar"], altitude: "1500 masl",
            lat: 9.6, lng: -83.9, rating: 8, isVerified: true
        ),
        Coffee(
            photoId: "sample-cerrado", status: "COMPLETE", errorMessage: nil, createdAt: "2024-11-18T09:00:00Z",
            roaster: "Field Notes Coffee", coffeeName: "Cerrado", originCountry: "Brazil", originRegion: "Minas Gerais",
            roastDate: "2024-11", roastLevel: "medium-dark", process: "Natural", variety: "Mundo Novo",
            flavorNotes: ["Peanut", "Dark Chocolate", "Cherry"], altitude: nil,
            lat: -18.5, lng: -46.5, rating: 7, isVerified: false
        ),
        Coffee(
            photoId: "sample-geisha", status: "COMPLETE", errorMessage: nil, createdAt: "2025-01-09T09:00:00Z",
            roaster: "Cardinal & Co.", coffeeName: "Esmeralda Geisha", originCountry: "Panama", originRegion: "Boquete",
            roastDate: "2025-01", roastLevel: "light", process: "Washed", variety: "Geisha",
            flavorNotes: ["Jasmine", "Bergamot", "Tropical"], altitude: "1700 masl",
            lat: 8.8, lng: -82.4, rating: 10, isVerified: true
        ),
        Coffee(
            photoId: "sample-batak", status: "COMPLETE", errorMessage: nil, createdAt: "2024-10-22T09:00:00Z",
            roaster: "Drift Roasters", coffeeName: "Blue Batak", originCountry: "Indonesia", originRegion: "Sumatra",
            roastDate: "2024-10", roastLevel: "dark", process: "Wet-Hulled", variety: "Ateng",
            flavorNotes: ["Cedar", "Tobacco", "Dark Cocoa"], altitude: nil,
            lat: 2.6, lng: 98.9, rating: 7, isVerified: false
        ),
    ]
}
#endif
