import SwiftUI

/// Bottom drawer: pick Describe or Photo. Describe expands the drawer into live transcription.
struct AddFoodSheet: View {
    enum Mode { case menu, voice }

    let onDescription: (String) -> Void
    let onCamera: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var detent: PresentationDetent

    private static let menuDetent = PresentationDetent.height(290)

    init(initialMode: Mode, onDescription: @escaping (String) -> Void, onCamera: @escaping () -> Void) {
        self.onDescription = onDescription
        self.onCamera = onCamera
        _mode = State(initialValue: initialMode)
        _detent = State(initialValue: initialMode == .voice ? .medium : Self.menuDetent)
    }

    var body: some View {
        Group {
            switch mode {
            case .menu:
                menu
            case .voice:
                VoiceCaptureView(
                    onDone: { text in
                        onDescription(text)
                        dismiss()
                    },
                    onCancel: { dismiss() }
                )
            }
        }
        .presentationDetents([Self.menuDetent, .medium], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    private var menu: some View {
        VStack(spacing: 20) {
            Text("What did you eat?")
                .font(.title3.weight(.semibold))
                .padding(.top, 28)
            HStack(spacing: 16) {
                OptionCard(icon: "mic.fill", title: "Describe it", subtitle: "Just say what you ate", tint: .green) {
                    withAnimation(.snappy) {
                        mode = .voice
                        detent = .medium
                    }
                }
                OptionCard(icon: "camera.fill", title: "Photo", subtitle: "Snap your plate", tint: .blue) {
                    onCamera()
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
    }
}

private struct OptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(tint.gradient, in: Circle())
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
