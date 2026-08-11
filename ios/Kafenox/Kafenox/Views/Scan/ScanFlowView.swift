import SwiftUI

/// Hosts the full-screen Scan -> Uploading -> Queued flow, switching on
/// ScanViewModel.step. Presented via .fullScreenCover from the tab bar's
/// floating scan button; dismissing this view (X button, or once the upload
/// is queued) returns to whichever tab was active.
struct ScanFlowView: View {
    let viewModel: ScanViewModel
    var onQueued: () -> Void
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
            case .uploading, .failed:
                ScanningView(viewModel: viewModel, onClose: onClose)
                    .overlay(alignment: .topLeading) {
                        closeButton
                    }
            case .queued:
                QueuedConfirmationView(onDone: onQueued)
            }
        }
        .onDisappear { viewModel.cancelUpload() }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .padding(.top, 14)
        .padding(.leading, 16)
    }
}
