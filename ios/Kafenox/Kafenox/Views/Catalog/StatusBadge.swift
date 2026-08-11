import SwiftUI

/// Extraction state for a catalog row, in place of the rating: a queued scan
/// has no rating to show yet, and a freshly extracted one is worth flagging
/// until the user has looked at it.
enum CoffeeStatusBadge {
    case processing
    case new
    case failed

    /// nil for a plain, already-reviewed coffee -- show the rating instead.
    init?(coffee: Coffee) {
        if coffee.isProcessing {
            self = .processing
        } else if coffee.isFailedExtraction {
            self = .failed
        } else if coffee.isNew {
            self = .new
        } else {
            return nil
        }
    }
}

struct StatusBadgeView: View {
    let kind: CoffeeStatusBadge
    let palette: Palette

    var body: some View {
        HStack(spacing: 5) {
            if kind == .processing {
                ProgressView()
                    .controlSize(.mini)
                    .tint(palette.muted)
            }
            Text(label)
                .font(.app(11, weight: .semibold))
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(background, in: Capsule())
    }

    private var label: String {
        switch kind {
        case .processing: return "Processing"
        case .new: return "New"
        case .failed: return "Failed"
        }
    }

    private var foreground: Color {
        switch kind {
        case .processing: return palette.muted
        case .new: return Palette.success
        case .failed: return Palette.error
        }
    }

    private var background: Color {
        switch kind {
        case .processing: return palette.surface2
        case .new: return Palette.success.opacity(0.14)
        case .failed: return Palette.error.opacity(0.14)
        }
    }
}
