import Foundation
import KafenoxCore

/// Runtime knobs for the API client. The base URL itself is build-time
/// configuration and lives in `AppConfiguration` (fed by Config/*.xcconfig),
/// so no environment URL is hardcoded here.
public enum APIConfig {
    public static var baseURL: URL { AppConfiguration.current.apiBaseURL }

    /// Provisioned once out-of-band (`aws apigateway get-api-key --include-value`)
    /// and stored in the Keychain -- never committed, never in UserDefaults.
    public static var apiKey: String {
        KeychainStore.get() ?? ""
    }

    /// When true, the Catalog (and therefore Insights, which derives from the
    /// same list) loads bundled sample coffees instead of calling the real
    /// API -- useful for UI work with no backend deployed yet or an empty
    /// table. The #if DEBUG guard makes this impossible to ship true in a
    /// Release/App Store build regardless of this constant's value, since
    /// DEBUG is never defined in Release configurations.
    #if DEBUG
    public static let useMockData = false
    #else
    public static let useMockData = false
    #endif
}
