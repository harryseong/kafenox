import KafenoxDesignSystem
import SwiftUI

struct ScanningView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: ScanViewModel
    var onClose: () -> Void

    @State private var sweepUp = false
    @State private var spin = false

    var body: some View {
        ZStack {
            Color(hex: 0x0c0c0c).ignoresSafeArea()

            VStack(spacing: 0) {
                if case .failed(let message) = viewModel.step {
                    failedState(message: message)
                } else {
                    scanningState
                }
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                sweepUp = true
            }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }

    private var scanningState: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0x1f1f1f))
                    .frame(width: 150, height: 203)
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 203)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .opacity(0.6)
                }
                Rectangle()
                    .fill(
                        LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 150, height: 3)
                    .offset(y: sweepUp ? 100 : -100)
                    .shadow(color: .white.opacity(0.8), radius: 7)
            }
            .padding(.top, 14)

            HStack(spacing: 10) {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(.white, lineWidth: 2.5)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(spin ? 360 : 0))
                    )
                Text("Uploading photo")
                    .font(.app(16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Reading the label happens in the background")
                .font(.app(12.5))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()
        }
    }

    private func failedState(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Palette.error)
                .accessibilityHidden(true)
            Text(message)
                .font(.app(16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                viewModel.retake()
            } label: {
                Text("Try again")
                    .font(.app(14.5, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0c0c0c))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(.app(14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
