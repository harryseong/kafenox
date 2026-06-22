import SwiftUI

struct ScanningView: View {
    @Environment(ThemeStore.self) private var themeStore
    let viewModel: ScanViewModel
    var onClose: () -> Void

    @State private var sweepUp = false
    @State private var spin = false

    var body: some View {
        let palette = themeStore.palette
        ZStack {
            Color(hex: 0x0c0b0b).ignoresSafeArea()

            VStack(spacing: 0) {
                if case .failed(let message) = viewModel.step {
                    failedState(message: message, palette: palette)
                } else {
                    scanningState(palette: palette)
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

    private func scanningState(palette: Palette) -> some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0x2a2522))
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
                        LinearGradient(colors: [.clear, palette.accent, .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: 150, height: 3)
                    .offset(y: sweepUp ? 100 : -100)
                    .shadow(color: palette.accent, radius: 8)
            }
            .padding(.top, 14)

            HStack(spacing: 10) {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: 0.25)
                            .stroke(palette.accent, lineWidth: 2.5)
                            .frame(width: 18, height: 18)
                            .rotationEffect(.degrees(spin ? 360 : 0))
                    )
                Text("Reading label with AI")
                    .font(.hanken(16, weight: 700))
                    .foregroundStyle(.white)
            }

            Text("Extracting details from the label")
                .font(.hanken(12.5))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()
        }
    }

    private func failedState(message: String, palette: Palette) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(palette.accent)
            Text(message)
                .font(.hanken(16, weight: 700))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Button {
                viewModel.retake()
            } label: {
                Text("Try again")
                    .font(.hanken(15, weight: 700))
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 15))
            }
            Button {
                onClose()
            } label: {
                Text("Cancel")
                    .font(.hanken(14, weight: 600))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
