import SwiftUI

@Observable
final class ThemeStore {
    private static let storageKey = "kafenox.theme"

    var choice: ThemeChoice {
        didSet { UserDefaults.standard.set(choice.rawValue, forKey: Self.storageKey) }
    }

    /// Mirrors the device appearance; RootView keeps it in sync from the
    /// SwiftUI environment so `system` can resolve without every view
    /// re-reading `colorScheme`.
    var systemIsDark = false

    var resolvedTheme: Theme {
        switch choice {
        case .light: .light
        case .dark: .dark
        case .system: systemIsDark ? .dark : .light
        }
    }

    var palette: Palette { .for(resolvedTheme) }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        // "light"/"dark" persisted by the previous toggle carry over; values
        // from the retired 3-theme system ("warm"/"minimal") fall to light.
        choice = stored.flatMap(ThemeChoice.init(rawValue:)) ?? .light
    }
}
