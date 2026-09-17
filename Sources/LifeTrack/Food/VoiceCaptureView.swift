import SwiftUI

/// Listening screen inside the drawer: prompt, live transcript, waveform, camera toggle.
/// Starts listening as soon as it appears. Tapping the waveform pauses and resumes.
struct VoiceCaptureView: View {
    let recognizer: SpeechRecognizer
    let onDone: (String) -> Void
    let onCancel: () -> Void
    let onCamera: () -> Void

    private var installer: SpeechModelInstaller { .shared }

    private var transcript: String {
        recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    recognizer.stop()
                    onCancel()
                }
                Spacer()
                status
                Spacer()
                Button("Done") {
                    recognizer.stop()
                    onDone(transcript)
                }
                .fontWeight(.semibold)
                .disabled(transcript.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            Spacer(minLength: 10)

            Text("What did you eat?")
                .font(.title2.weight(.semibold))

            ScrollView {
                Text(transcript.isEmpty ? placeholder : transcript)
                    .font(.title3)
                    .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .animation(.default, value: transcript)
            }
            .frame(maxHeight: 96)
            .padding(.top, 8)

            Spacer(minLength: 6)

            if case .unavailable(let message) = recognizer.state {
                Unavailable(message: message)
                    .padding(.horizontal, 24)
                    .frame(height: 104)
            } else {
                Button {
                    if recognizer.isListening {
                        recognizer.stop()
                    } else {
                        Task { await recognizer.start() }
                    }
                } label: {
                    Waveform(level: recognizer.level, active: recognizer.isListening)
                        .frame(height: 72)
                        .padding(.horizontal, 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(recognizer.isListening ? "Pause listening" : "Start listening")

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 32, alignment: .top)
            }

            Spacer(minLength: 6)

            Button(action: onCamera) {
                HStack(spacing: 10) {
                    Image(systemName: "camera")
                    Text("Switch to camera")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .task { await recognizer.start() }
        .onDisappear { recognizer.stop() }
    }

    @ViewBuilder
    private var status: some View {
        switch recognizer.state {
        case .idle, .requestingPermission:
            Text("Starting…").font(.subheadline).foregroundStyle(.secondary)
        case .preparing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Preparing").font(.subheadline).foregroundStyle(.secondary)
            }
        case .listening:
            HStack(spacing: 6) {
                Circle().fill(.primary).frame(width: 8, height: 8)
                Text("Listening").font(.subheadline.weight(.medium))
            }
        case .paused:
            Text("Paused").font(.subheadline).foregroundStyle(.secondary)
        case .failed:
            Text("Didn't work").font(.subheadline).foregroundStyle(.secondary)
        case .unavailable:
            Text("Unavailable").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var placeholder: String {
        switch recognizer.state {
        case .listening: return "Listening…"
        case .paused: return "Paused. Tap the wave to keep going."
        case .preparing(let message):
            if installer.status == .downloading {
                return message + " " + installer.progress.formatted(.percent.precision(.fractionLength(0)))
            }
            return message
        case .failed(let message):
            return message.hasSuffix(".") ? message : message + "."
        default: return "Starting…"
        }
    }

    private var caption: String {
        switch recognizer.state {
        case .listening: return "Tap to pause"
        case .paused: return "Tap to continue"
        case .failed: return "Tap to try again"
        default: return " "
        }
    }
}

private struct Unavailable: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}
