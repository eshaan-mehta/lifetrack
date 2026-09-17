import AVFoundation
import Foundation
import Observation
import Speech

/// Live speech-to-text from the microphone. Partial results land in `transcript` as they arrive.
/// Can be paused and resumed; text from earlier runs is kept and new speech is appended.
@MainActor
@Observable
final class SpeechRecognizer {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case paused
        /// Something went wrong mid-run, e.g. no network for recognition. Worth retrying.
        case failed(String)
        /// Permission denied. Only Settings can fix it.
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    /// Smoothed microphone level, 0 to 1, for the pulse animation.
    private(set) var level: Float = 0

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer()
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Text locked in from previous runs; the current run appends to it.
    @ObservationIgnored private var committed = ""
    @ObservationIgnored private var userStopped = false

    var isListening: Bool { state == .listening }

    func start() async {
        guard request == nil else { return }
        userStopped = false
        state = .requestingPermission

        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speechAuthorized else {
            state = .unavailable("Speech recognition is turned off for LifeTrack.")
            return
        }
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .unavailable("Microphone access is turned off for LifeTrack.")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .failed("Speech recognition isn't available right now. Check your connection.")
            return
        }
        do {
            try listen(with: recognizer)
            state = .listening
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Pause. Keeps the transcript so listening can resume and append.
    func stop() {
        guard request != nil else { return }
        userStopped = true
        tearDown()
        if state == .listening { state = .paused }
    }

    private func listen(with recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.level(of: buffer)
            Task { @MainActor in self?.update(level: level) }
        }
        engine.prepare()
        try engine.start()

        let base = committed
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.transcript = base.isEmpty ? text : base + " " + text
                }
                if let error, !self.userStopped {
                    // The recognizer gave up on its own (timeout, network, silence).
                    self.tearDown()
                    self.state = self.transcript.isEmpty ? .failed(Self.describe(error)) : .paused
                } else if result?.isFinal == true {
                    self.tearDown()
                    if self.state == .listening { self.state = .paused }
                }
            }
        }
    }

    private func tearDown() {
        guard request != nil else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        committed = transcript
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func update(level new: Float) {
        level = level * 0.6 + new * 0.4
    }

    private static func describe(_ error: Error) -> String {
        let text = error.localizedDescription
        return text.isEmpty ? "Listening stopped unexpectedly." : text
    }

    /// RMS of the buffer mapped from roughly -50 dB...0 dB onto 0...1.
    nonisolated private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += channel[i] * channel[i] }
        let rms = (sum / Float(count)).squareRoot()
        let db = 20 * log10(max(rms, 1e-6))
        return max(0, min(1, (db + 50) / 50))
    }
}
