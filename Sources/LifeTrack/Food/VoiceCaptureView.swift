import SwiftUI

/// Listens as soon as it appears and shows the words live so they can be checked.
/// The mic button pauses and resumes; Done hands the text back.
struct VoiceCaptureView: View {
    let onDone: (String) -> Void
    let onCancel: () -> Void

    @State private var recognizer = SpeechRecognizer()

    private var transcript: String {
        recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 16) {
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
            .padding(.top, 20)

            ScrollView {
                Text(transcript.isEmpty ? "Say what you ate, like “two eggs and a slice of toast”." : transcript)
                    .font(.title2)
                    .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .animation(.default, value: transcript)
            }

            if case .unavailable(let message) = recognizer.state {
                Unavailable(message: message)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            } else {
                VStack(spacing: 10) {
                    Button {
                        if recognizer.isListening {
                            recognizer.stop()
                        } else {
                            Task { await recognizer.start() }
                        }
                    } label: {
                        MicPulse(level: recognizer.level, active: recognizer.isListening)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(recognizer.isListening ? "Pause listening" : "Start listening")

                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 16)
            }
        }
        .task { await recognizer.start() }
        .onDisappear { recognizer.stop() }
    }

    @ViewBuilder
    private var status: some View {
        switch recognizer.state {
        case .idle, .requestingPermission:
            Text("Starting…").font(.subheadline).foregroundStyle(.secondary)
        case .listening:
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
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

    private var hint: String {
        switch recognizer.state {
        case .listening: return "Tap to pause"
        case .paused: return "Tap to keep going"
        case .failed(let message):
            let sentence = message.hasSuffix(".") ? message : message + "."
            return sentence + " Tap to try again."
        default: return " "
        }
    }
}

private struct MicPulse: View {
    let level: Float
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .scaleEffect(active ? 1 + CGFloat(level) * 0.9 : 1)
                .animation(.easeOut(duration: 0.08), value: level)
            Circle()
                .fill(Color.green.opacity(0.25))
                .scaleEffect(active ? 1 + CGFloat(level) * 0.5 : 1)
                .animation(.easeOut(duration: 0.08), value: level)
            Image(systemName: active ? "mic.fill" : "mic")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(active ? Color.green.gradient : Color.gray.gradient, in: Circle())
        }
        .frame(width: 96, height: 96)
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
