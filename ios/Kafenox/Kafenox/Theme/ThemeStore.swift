import SwiftUI

@Observable
final class ThemeStore {
    private static let storageKey = "kafenox.theme"

    var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    var palette: Palette { .for(theme) }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        // Values persisted by the retired 3-theme system ("warm"/"minimal")
        // fall through to light; "dark" still parses.
        theme = stored.flatMap(Theme.init(rawValue:)) ?? .light
    }

    func toggle() {
        theme = theme.toggled()
    }
}
