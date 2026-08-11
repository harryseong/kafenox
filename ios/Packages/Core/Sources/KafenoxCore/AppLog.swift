import Foundation
import OSLog

/// One logger per subsystem, defined once. `print()` never ships -- it is
/// invisible in Console.app, unfilterable, and has no privacy handling.
///
/// Interpolations are redacted by default; mark a value `privacy: .public`
/// only when it genuinely carries no user data (status strings, HTTP codes).
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.harryseong.kafenox"

    public static let scan = Logger(subsystem: subsystem, category: "scan")
    public static let uploadQueue = Logger(subsystem: subsystem, category: "upload-queue")
    public static let catalog = Logger(subsystem: subsystem, category: "catalog")
    public static let networking = Logger(subsystem: subsystem, category: "networking")
    public static let insights = Logger(subsystem: subsystem, category: "insights")
}
