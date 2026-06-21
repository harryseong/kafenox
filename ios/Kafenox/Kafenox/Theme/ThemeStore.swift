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
        theme = stored.flatMap(Theme.init(rawValue:)) ?? .warm
    }

    func cycle() {
        theme = theme.next()
    }
}
