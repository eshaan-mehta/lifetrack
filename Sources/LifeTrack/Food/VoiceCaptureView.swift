import SwiftUI

/// Listening screen inside the drawer. Starts listening on appear and shows words live over
/// a waveform. When you stop talking for a couple of seconds (or tap the wave) the waveform
/// goes away and the text becomes editable in place, with keep-talking and send buttons.
struct VoiceCaptureView: View {
    let recognizer: SpeechRecognizer
    let onDone: (String) -> Void
    let onCancel: () -> Void
    let onCamera: () -> Void

    @State private var draft = ""
    @State private var userEdited = false
    @FocusState private var editorFocused: Bool

    private var installer: SpeechModelInstaller { .shared }

    private var transcript: String {
        recognizer.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Listening has ended and there is something to show.
    private var reviewing: Bool {
        switch recognizer.state {
        case .paused, .failed: return recognizer.hasSpeech
        default: return false
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                header
                Spacer(minLength: 10)
                Text("What did you eat?")
                    .font(.title2.weight(.semibold))
                if reviewing {
                    editor
                } else {
                    liveText
                    Spacer(minLength: 6)
                    listeningControl
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, DrawerControls.rowHeight + DrawerControls.bottomPadding)

            bottomRow
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            if DebugFlags.demoTranscript {
                recognizer.seed(transcript: "Two eggs, a slice of toast with butter and a black coffee")
            } else {
                await recognizer.start()
            }
        }
        .onDisappear { recognizer.stop() }
        .onChange(of: reviewing) { _, now in
            if now {
                draft = transcript
                userEdited = false
            }
        }
        .onChange(of: recognizer.transcript) { _, _ in
            // Late finalized words can land just after listening stops; take them unless
            // the user has already started editing.
            if reviewing && !userEdited { draft = transcript }
        }
        .onChange(of: draft) { _, new in
            if reviewing && new != transcript { userEdited = true }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button("Cancel") {
                recognizer.stop()
                onCancel()
            }
            Spacer()
            status
            Spacer()
            // Balances the Cancel button so the status stays centered.
            Text("Cancel").hidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var liveText: some View {
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
    }

    /// The transcript, in the same place and type as the live text, now editable.
    private var editor: some View {
        TextEditor(text: $draft)
            .font(.title3)
            .multilineTextAlignment(.center)
            .scrollContentBackground(.hidden)
            .focused($editorFocused)
            .frame(maxHeight: 150)
            .padding(.horizontal, 20)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var listeningControl: some View {
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
            .accessibilityLabel(recognizer.isListening ? "Stop listening" : "Start listening")

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(minHeight: 32, alignment: .top)
        }
    }

    /// While listening, a Voice / Camera pill spans the row. In review the row becomes
    /// keep-talking on the left and send on the right.
    private var bottomRow: some View {
        HStack {
            if reviewing {
                RoundGlyphButton(systemImage: "mic.fill", label: "Keep talking", action: resume)
                Spacer()
                RoundGlyphButton(systemImage: "arrow.up", label: "Send", prominent: true, action: send)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                ModePill(selected: .voice) { mode in
                    if mode == .camera { onCamera() }
                }
            }
        }
        .frame(height: DrawerControls.rowHeight)
        .padding(.horizontal, DrawerControls.horizontalPadding)
        .padding(.bottom, DrawerControls.bottomPadding)
        .animation(.snappy, value: reviewing)
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
            Text(reviewing ? "Check and send" : "Paused")
                .font(.subheadline).foregroundStyle(.secondary)
        case .failed:
            Text(reviewing ? "Check and send" : "Didn't work")
                .font(.subheadline).foregroundStyle(.secondary)
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
        case .listening: return "Stops on its own when you pause. Tap to stop now."
        case .paused: return "Tap to continue"
        case .failed: return "Tap to try again"
        default: return " "
        }
    }

    // MARK: Actions

    private func resume() {
        editorFocused = false
        if reviewing {
            recognizer.replaceTranscript(draft.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        Task { await recognizer.start() }
    }

    private func send() {
        editorFocused = false
        recognizer.stop()
        onDone(draft.trimmingCharacters(in: .whitespacesAndNewlines))
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
