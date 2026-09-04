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
                picker.cameraOverlayView = overlay
                referenceOverlay = overlay
            }
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

private final class CameraReferenceOverlayView: UIView {
    let imageView: UIImageView

    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 72),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -160),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.42)
        ])
    }

    required init?(coder: NSCoder) { nil }
}
