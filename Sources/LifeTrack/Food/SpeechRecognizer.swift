import AVFoundation
import Foundation
import Observation
import Speech

/// Live on-device speech-to-text using iOS 26's SpeechAnalyzer with the DictationTranscriber
/// module, which is tuned for short spoken phrases and streams words with low latency.
/// Partial ("volatile") text shows as you speak and is replaced by finalized text.
/// Stops on its own after a couple of seconds of silence once something has been said.
/// Can be paused and resumed; text from earlier runs is kept and new speech is appended.
@MainActor
@Observable
final class SpeechRecognizer {
    enum State: Equatable {
        case idle
        case requestingPermission
        /// One-time model download for the language, or warming up.
        case preparing(String)
        case listening
        case paused
        /// Something went wrong mid-run. Worth retrying.
        case failed(String)
        /// Permission denied. Only Settings can fix it.
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    /// Smoothed microphone level, 0 to 1, for the waveform.
    private(set) var level: Float = 0

    /// Quiet time, after something has been said, before listening ends on its own.
    var silenceTimeout: TimeInterval = 2.0

    var isListening: Bool { state == .listening }

    /// True once the transcript holds an actual word, not just punctuation the model
    /// sometimes emits for background noise.
    var hasSpeech: Bool {
        transcript.contains { $0.isLetter || $0.isNumber }
    }

    private struct Run {
        let analyzer: SpeechAnalyzer
        let input: AsyncStream<AnalyzerInput>.Continuation
    }

    /// Raw level above which a buffer counts as speech for silence detection.
    private static let speechLevel: Float = 0.3

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var run: Run?
    @ObservationIgnored private var resultsTask: Task<Void, Never>?
    @ObservationIgnored private var silenceTask: Task<Void, Never>?
    @ObservationIgnored private var lastActivity = Date()
    /// Text locked in from previous runs.
    @ObservationIgnored private var committed = ""
    /// Finalized text from the current run, and the current best guess for what follows it.
    @ObservationIgnored private var finalized = ""
    @ObservationIgnored private var volatile = ""
    @ObservationIgnored private var userStopped = false

    func start() async {
        guard run == nil else { return }
        // Let the previous run drain its last results and commit before appending to them.
        if let previous = resultsTask {
            await previous.value
        }
        userStopped = false
        state = .requestingPermission

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .unavailable("Microphone access is turned off for LifeTrack.")
            return
        }
        let locale: Locale
        do {
            // Usually instant: the model was downloaded in the background at first launch.
            state = .preparing("Downloading the speech model…")
            locale = try await SpeechModelInstaller.shared.ensureInstalled()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            state = .failed("No compatible audio format for transcription.")
            return
        }

        state = .preparing("Getting ready…")
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()

        resultsTask = Task { @MainActor [weak self] in
            do {
                for try await result in transcriber.results {
                    self?.handle(result)
                }
            } catch {
                self?.runFailed(error)
            }
            self?.commitRun()
        }

        do {
            try await analyzer.prepareToAnalyze(in: format)
            try await analyzer.start(inputSequence: stream)
            try startEngine(feeding: continuation, format: format)
            run = Run(analyzer: analyzer, input: continuation)
            state = .listening
            watchForSilence()
        } catch {
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            stopEngine()
            state = .failed(error.localizedDescription)
        }
    }

    /// Stop listening. Keeps the transcript so listening can resume and append.
    func stop() {
        guard let run else { return }
        self.run = nil
        userStopped = true
        silenceTask?.cancel()
        silenceTask = nil
        stopEngine()
        run.input.finish()
        Task { try? await run.analyzer.finalizeAndFinishThroughEndOfInput() }
        if state == .listening { state = .paused }
    }

    /// Replace the text, e.g. after the user edited it, so further speech appends to the edit.
    /// Only while not listening.
    func replaceTranscript(_ text: String) {
        guard run == nil else { return }
        committed = text
        finalized = ""
        volatile = ""
        transcript = text
    }

    /// Debug only: pretend a run just ended with this text.
    func seed(transcript text: String) {
        replaceTranscript(text)
        state = .paused
    }

    // MARK: Silence detection

    private func watchForSilence() {
        lastActivity = Date()
        silenceTask?.cancel()
        silenceTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.isListening else { return }
                if self.hasSpeech,
                   Date().timeIntervalSince(self.lastActivity) >= self.silenceTimeout {
                    self.stop()
                    return
                }
            }
        }
    }

    // MARK: Audio engine

    private func startEngine(feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
                             format: AVAudioFormat) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        // The mic almost never matches the analyzer's format; convert every buffer.
        let converter = inputFormat == format ? nil : AVAudioConverter(from: inputFormat, to: format)

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            let level = Self.level(of: buffer)
            Task { @MainActor in self?.update(level: level) }
            if let converter {
                if let converted = Self.convert(buffer, with: converter, to: format) {
                    continuation.yield(AnalyzerInput(buffer: converted))
                }
            } else {
                continuation.yield(AnalyzerInput(buffer: buffer))
            }
        }
        engine.prepare()
        try engine.start()
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        level = 0
    }

    // MARK: Results

    private func handle(_ result: DictationTranscriber.Result) {
        let text = String(result.text.characters)
        if result.isFinal {
            finalized = Self.join(finalized, text)
            volatile = ""
        } else {
            volatile = text
        }
        let updated = Self.join(Self.join(committed, finalized), volatile)
        if updated != transcript {
            transcript = updated
            lastActivity = Date()
        }
    }

    private func runFailed(_ error: Error) {
        guard !userStopped else { return }
        run?.input.finish()
        run = nil
        silenceTask?.cancel()
        stopEngine()
        let text = error.localizedDescription
        state = hasSpeech
            ? .paused
            : .failed(text.isEmpty ? "Listening stopped unexpectedly." : text)
    }

    private func commitRun() {
        committed = Self.join(Self.join(committed, finalized), volatile)
        finalized = ""
        volatile = ""
        transcript = committed
        resultsTask = nil
    }

    private func update(level new: Float) {
        level = level * 0.6 + new * 0.4
        if new > Self.speechLevel {
            lastActivity = Date()
        }
    }

    private static func join(_ a: String, _ b: String) -> String {
        let tail = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return tail }
        if tail.isEmpty { return a }
        return a + " " + tail
    }

    // MARK: Audio helpers (audio thread)

    nonisolated private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                            to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, error == nil, output.frameLength > 0 else { return nil }
        return output
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
