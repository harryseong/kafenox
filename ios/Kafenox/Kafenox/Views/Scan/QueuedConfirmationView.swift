import SwiftUI

/// Brief confirmation shown once a photo is uploaded, before dropping the
/// user back into the catalog. Extraction is still running at this point --
/// the queued row and its notification are what report the result.
struct QueuedConfirmationView: View {
    var onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(hex: 0x0c0c0c).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.success)
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                Text("Added to the queue")
                    .font(.app(18, weight: .semibold))
                    .foregroundStyle(.white)

                Text("We'll read the label in the background and let you know when it's ready.")
                    .font(.app(13))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .task {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { appeared = true }
            try? await Task.sleep(for: .milliseconds(1300))
            onDone()
        }
    }
}
