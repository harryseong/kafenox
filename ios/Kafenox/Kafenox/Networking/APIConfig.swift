import Foundation

/// Base URL points at the deployed API Gateway stage. Update once the
/// backend is deployed (see backend/README or `cdk deploy` output for the
/// stage URL) -- swap to an Info.plist/xcconfig-driven value per scheme if
/// dev/prod stages diverge.
enum APIConfig {
    static let baseURL = URL(string: "https://ivtb3d1a1f.execute-api.ap-southeast-1.amazonaws.com/dev")!

    static var apiKey: String {
        KeychainStore.get() ?? ""
    }

    /// When true, the Catalog (and therefore Map, which derives from the
    /// same list) loads bundled sample coffees instead of calling the real
    /// API -- useful for UI work with no backend deployed yet or an empty
    /// table. The #if DEBUG guard makes this impossible to ship true in a
    /// Release/App Store build regardless of this constant's value, since
    /// DEBUG is never defined in Release configurations.
    #if DEBUG
    static let useMockData = true
    #else
    static let useMockData = false
    #endif
}
