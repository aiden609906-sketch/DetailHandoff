import AVFoundation
import SwiftUI
import UIKit

enum CameraPickerError: LocalizedError {
    case unavailable
    case permissionDenied
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "This device does not have a camera available."
        case .permissionDenied:
            "Camera access is turned off. Enable it in Settings to take a photo."
        case .captureFailed:
            "The camera did not return a usable photo. Please try again."
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var referenceOpacity: Double

    let referenceImageData: Data?
    let onResult: (Result<Data, CameraPickerError>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        context.coordinator.configure(picker)
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.updateReference(on: picker, opacity: referenceOpacity)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private var parent: CameraPicker
        private weak var referenceOverlay: CameraReferenceOverlayView?

        init(parent: CameraPicker) { self.parent = parent }

        func configure(_ picker: UIImagePickerController) {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                finish(.failure(.unavailable))
                return
            }
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.allowsEditing = false
            updateReference(on: picker, opacity: parent.referenceOpacity)

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                break
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self, weak picker] allowed in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        guard allowed else {
                            self.finish(.failure(.permissionDenied))
                            return
                        }
                        if let picker { self.configure(picker) }
                    }
                }
            case .denied, .restricted:
                finish(.failure(.permissionDenied))
            @unknown default:
                finish(.failure(.permissionDenied))
            }
        }

        func updateReference(on picker: UIImagePickerController, opacity: Double) {
            guard let data = parent.referenceImageData, let image = UIImage(data: data) else {
                picker.cameraOverlayView = nil
                referenceOverlay = nil
                return
            }
            let overlay: CameraReferenceOverlayView
            if let referenceOverlay {
                overlay = referenceOverlay
            } else {
                overlay = CameraReferenceOverlayView(image: image)
                overlay.updateLayout(in: picker.view.bounds, safeAreaInsets: picker.view.safeAreaInsets)
                picker.cameraOverlayView = overlay
                referenceOverlay = overlay
            }
            overlay.updateLayout(in: picker.view.bounds, safeAreaInsets: picker.view.safeAreaInsets)
            overlay.imageView.alpha = opacity
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.95) else {
                finish(.failure(.captureFailed))
                return
            }
            finish(.success(data))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }

        private func finish(_ result: Result<Data, CameraPickerError>) {
            parent.isPresented = false
            parent.onResult(result)
        }
    }
}

final class CameraReferenceOverlayView: UIView {
    let imageView: UIImageView
    private var presentationInsets = UIEdgeInsets.zero

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)
    }

    func updateLayout(in presentationBounds: CGRect, safeAreaInsets: UIEdgeInsets) {
        frame = CGRect(origin: .zero, size: presentationBounds.size)
        presentationInsets = safeAreaInsets
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Autoresizing follows the camera host on rotation; keep the reference above its controls.
        let top = max(72, presentationInsets.top + 16)
        let bottom = max(160, presentationInsets.bottom + 120)
        let left = presentationInsets.left + 24
        let right = presentationInsets.right + 24
        imageView.frame = CGRect(
            x: left,
            y: top,
            width: max(0, bounds.width - left - right),
            height: min(bounds.height * 0.42, max(0, bounds.height - top - bottom))
        )
    }

    required init?(coder: NSCoder) { nil }
}
