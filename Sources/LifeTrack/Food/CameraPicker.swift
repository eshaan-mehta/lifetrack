import PhotosUI
import SwiftUI
import UIKit

/// Camera when there is one, otherwise the photo library (the Simulator has no camera).
struct PhotoCapture: View {
    let onImage: (UIImage) -> Void

    var body: some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            CameraPicker(onImage: onImage)
        } else {
            LibraryFallback(onImage: onImage)
        }
    }
}

/// The system camera, including its own Retake / Use Photo confirmation.
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct LibraryFallback: View {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "camera.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No camera on this device. Pick a photo instead.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                PhotosPicker("Choose Photo", selection: $selection, matching: .images)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selection) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onImage(image)
                    }
                    dismiss()
                }
            }
        }
    }
}
