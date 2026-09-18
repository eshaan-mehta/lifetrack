import SwiftUI
import UIKit

/// Bottom drawer for logging food. Opens straight into listening. A wide toggle at the
/// bottom switches to an in-drawer camera, and the camera's back button returns.
struct AddFoodSheet: View {
    enum Mode { case voice, camera }

    let onDescription: (String) -> Void
    let onPhoto: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var detent: PresentationDetent
    /// Lives here rather than in the voice view so the transcript survives a trip to the camera.
    @State private var recognizer = SpeechRecognizer()

    private static let voiceDetent = PresentationDetent.fraction(0.56)
    private static let cameraDetent = PresentationDetent.fraction(0.8)

    init(initialMode: Mode = .voice,
         onDescription: @escaping (String) -> Void,
         onPhoto: @escaping (UIImage) -> Void) {
        self.onDescription = onDescription
        self.onPhoto = onPhoto
        _mode = State(initialValue: initialMode)
        _detent = State(initialValue: initialMode == .camera ? Self.cameraDetent : Self.voiceDetent)
    }

    var body: some View {
        Group {
            switch mode {
            case .voice:
                VoiceCaptureView(
                    recognizer: recognizer,
                    onDone: { text in
                        onDescription(text)
                        dismiss()
                    },
                    onCancel: { dismiss() },
                    onCamera: { switchTo(.camera) }
                )
            case .camera:
                CameraView(
                    onPhoto: { image in
                        onPhoto(image)
                        dismiss()
                    },
                    onVoice: { switchTo(.voice) },
                    onCancel: { dismiss() }
                )
            }
        }
        // A single detent at a time: the drawer can be swiped away but never resized by hand.
        // Switching modes swaps the detent, and the sheet animates to the new height.
        .presentationDetents([detent], selection: $detent)
        .presentationDragIndicator(.visible)
        .tint(.primary)
    }

    private func switchTo(_ newMode: Mode) {
        if newMode == .camera { recognizer.stop() }
        withAnimation(.snappy) {
            mode = newMode
            detent = newMode == .camera ? Self.cameraDetent : Self.voiceDetent
        }
    }
}
