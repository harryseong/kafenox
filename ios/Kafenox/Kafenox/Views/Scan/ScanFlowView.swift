import SwiftUI

/// Hosts the full-screen Scan -> Scanning -> Review flow, switching on
/// ScanViewModel.step. Presented via .fullScreenCover from the tab bar's
/// floating scan button; dismissing this view (X button, or after a
/// successful "Add to collection") returns to whichever tab was active.
struct ScanFlowView: View {
    let viewModel: ScanViewModel
    var onAdd: (Coffee) -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            switch viewModel.step {
            case .capturing:
                ScanCameraView(
                    onCapture: { viewModel.didCapture($0) },
                    onCancel: onClose
                )
                .ignoresSafeArea()
            case .scanning, .failed:
                ScanningView(viewModel: viewModel, onClose: onClose)
                    .overlay(alignment: .topLeading) {
                        closeButton
                    }
            case .review:
                ReviewView(
                    viewModel: viewModel,
                    onAdd: onAdd,
                    onRetake: { viewModel.retake() }
                )
            }
        }
        .onDisappear { viewModel.cancelPolling() }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.25), in: Circle())
        }
        .padding(.top, 14)
        .padding(.leading, 16)
    }
}
