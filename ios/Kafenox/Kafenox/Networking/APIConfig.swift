import Foundation

/// Base URL points at the deployed API Gateway stage. Update once the
/// backend is deployed (see backend/README or `cdk deploy` output for the
/// stage URL) -- swap to an Info.plist/xcconfig-driven value per scheme if
/// dev/prod stages diverge.
enum APIConfig {
    static let baseURL = URL(string: "https://CHANGEME.execute-api.ap-southeast-1.amazonaws.com/dev")!

    static var apiKey: String {
        KeychainStore.get() ?? ""
    }
}
