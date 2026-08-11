import Foundation
import SwiftUI

/// The Bedrock Claude models the user can pick per feature in Settings.
/// Raw values are the short names the backend's model_prefs module maps to
/// concrete inference-profile ids.
public enum ModelChoice: String, CaseIterable, Identifiable, Sendable {
    case haiku, sonnet

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .haiku: "Claude Haiku"
        case .sonnet: "Claude Sonnet"
        }
    }

    public var tag: String {
        switch self {
        case .haiku: "Fastest"
        case .sonnet: "Most capable"
        }
    }
}

/// The AI-backed features a model can be chosen for.
public enum AIFeature: String, CaseIterable, Identifiable, Sendable {
    case scan, ask, notes

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .scan: "Scan"
        case .ask: "Insights · Ask AI"
        case .notes: "Flavor categorization"
        }
    }

    public var subtitle: String {
        switch self {
        case .scan: "Reads the label when you scan a bag"
        case .ask: "Chat grounded in your cupping log"
        case .notes: "Sorts flavor notes into note families"
        }
    }

    public var systemImage: String {
        switch self {
        case .scan: "camera"
        case .ask: "sparkle"
        case .notes: "text.badge.checkmark"
        }
    }

    /// Mirrors the backend's per-feature defaults (Haiku for extraction and
    /// categorization, Sonnet for open-ended Q&A).
    public var defaultModel: ModelChoice {
        self == .ask ? .sonnet : .haiku
    }
}

/// User-facing app settings persisted in UserDefaults. A shared instance is
/// used because non-view code (scan/ask view models) also reads the model
/// preferences when composing API requests.
@MainActor
@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    private static func key(for feature: AIFeature) -> String {
        "kafenox.aiModel.\(feature.rawValue)"
    }

    private var models: [AIFeature: ModelChoice]

    public init() {
        var loaded: [AIFeature: ModelChoice] = [:]
        for feature in AIFeature.allCases {
            let stored = UserDefaults.standard.string(forKey: Self.key(for: feature))
            loaded[feature] = stored.flatMap(ModelChoice.init(rawValue:)) ?? feature.defaultModel
        }
        models = loaded
    }

    public func model(for feature: AIFeature) -> ModelChoice {
        models[feature] ?? feature.defaultModel
    }

    public func setModel(_ model: ModelChoice, for feature: AIFeature) {
        models[feature] = model
        UserDefaults.standard.set(model.rawValue, forKey: Self.key(for: feature))
    }
}
