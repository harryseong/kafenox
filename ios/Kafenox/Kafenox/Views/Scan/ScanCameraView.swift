import SwiftUI
import UIKit

/// Native camera capture UI -- reliable, handles permissions/orientation for
/// us. The prototype's custom corner-bracket framing overlay is skipped in
/// favor of this; the novel parts of the design (Scanning, Review) are
/// fully custom and implemented as designed.
///
/// UIImagePickerController must be presented modally (`present(_:animated:)`)
/// to manage its internal AVCaptureSession correctly -- embedding it
/// directly as a representable's content (the obvious approach) leaves the
/// capture session torn down mid-transition right as you tap "Use Photo",
/// surfacing as a FigCaptureSourceRemote/-17281 failure. A plain container
/// controller that explicitly presents/dismisses the picker avoids that.
///
/// The present() call itself has to wait for viewDidAppear -- doing it from
/// updateUIViewController (the obvious next step) can fire before the
/// container's view is actually attached to a window, which fails silently
/// (black screen, "view is not in the window hierarchy" in the console).
struct ScanCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraContainerViewController {
        let container = CameraContainerViewController()
        container.onFirstAppear = { [weak container] in
            guard let container, container.presentedViewController == nil else { return }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = ["public.image"]
            picker.delegate = context.coordinator
            context.coordinator.picker = picker
            container.present(picker, animated: false)
        }
        return container
    }

    func updateUIViewController(_ uiViewController: CameraContainerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onCancel: () -> Void
        weak var picker: UIImagePickerController?

        init(onCapture: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: false) { [onCapture, onCancel] in
                if let image {
                    onCapture(image)
                } else {
                    onCancel()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: false) { [onCancel] in
                onCancel()
            }
        }
    }
}

/// Presents the camera picker from viewDidAppear, once, since that's the
/// first point at which this controller's view is guaranteed to be in the
/// window hierarchy.
final class CameraContainerViewController: UIViewController {
    var onFirstAppear: (() -> Void)?
    private var hasAppeared = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAppeared else { return }
        hasAppeared = true
        onFirstAppear?()
    }
}
