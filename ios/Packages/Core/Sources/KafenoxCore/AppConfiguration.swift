import Foundation

/// Build-time configuration, surfaced once as typed values instead of
/// scattered `Bundle.main.object(forInfoDictionaryKey:)` calls. Values come
/// from Config/*.xcconfig via Info.plist, so dev and prod stages differ
/// without a code change.
public struct AppConfiguration: Sendable {
    public let apiBaseURL: URL
    public let environment: Environment

    public enum Environment: String, Sendable {
        case debug, release
    }

    public init(apiBaseURL: URL, environment: Environment) {
        self.apiBaseURL = apiBaseURL
        self.environment = environment
    }

    /// Crashing at launch on missing/malformed configuration is deliberate:
    /// a silently-wrong base URL is far more expensive to diagnose than a
    /// startup failure caught on the first run.
    public static let current: AppConfiguration = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !host.isEmpty,
              let url = URL(string: "https://\(host)")
        else {
            preconditionFailure("API_BASE_URL missing or malformed in Info.plist -- check Config/*.xcconfig wiring")
        }
        #if DEBUG
        let environment = Environment.debug
        #else
        let environment = Environment.release
        #endif
        return AppConfiguration(apiBaseURL: url, environment: environment)
    }()
}
