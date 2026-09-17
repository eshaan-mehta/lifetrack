import Foundation
import Observation
import Speech

enum SpeechModelError: LocalizedError {
    case unavailable
    case unsupportedLanguage

    var errorDescription: String? {
        switch self {
        case .unavailable: return "On-device transcription isn't available on this device."
        case .unsupportedLanguage: return "Transcription isn't supported for your language yet."
        }
    }
}

/// Keeps the on-device speech model installed so voice capture starts instantly.
///
/// Apple's speech models are system assets that only iOS can download, so they can't ship
/// inside the app. The next best thing: kick the download off at first launch, in the
/// background, and reserve the locale so iOS keeps the model around. Voice capture awaits
/// the same shared task, so if it opens mid-download it just shows progress.
@MainActor
@Observable
final class SpeechModelInstaller {
    static let shared = SpeechModelInstaller()

    enum Status: Equatable {
        case unknown
        case downloading
        case ready
        case failed(String)
    }

    private(set) var status: Status = .unknown
    /// Download progress, 0 to 1. Only meaningful while `status == .downloading`.
    private(set) var progress: Double = 0
    private(set) var locale: Locale?

    @ObservationIgnored private var task: Task<Locale, Error>?
    @ObservationIgnored private var observation: NSKeyValueObservation?

    /// Starts the install if it hasn't started. Cheap to call repeatedly.
    func warmUp() {
        _ = installTask()
    }

    /// Resolves with the locale once the model is installed. Throws if the language is
    /// unsupported or the download fails; the next call retries.
    func ensureInstalled() async throws -> Locale {
        do {
            return try await installTask().value
        } catch {
            task = nil
            throw error
        }
    }

    private func installTask() -> Task<Locale, Error> {
        if let task { return task }
        let task = Task { try await install() }
        self.task = task
        return task
    }

    private func install() async throws -> Locale {
        do {
            guard let locale = await Self.pickLocale() else { throw SpeechModelError.unsupportedLanguage }
            self.locale = locale

            // Any transcriber for the locale works for asking about assets.
            let probe = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
            switch await AssetInventory.status(forModules: [probe]) {
            case .installed:
                break
            case .unsupported:
                throw SpeechModelError.unsupportedLanguage
            case .supported, .downloading:
                status = .downloading
                progress = 0
                _ = try? await AssetInventory.reserve(locale: locale)
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                    observe(request.progress)
                    defer { observation = nil }
                    try await request.downloadAndInstall()
                }
            @unknown default:
                break
            }
            status = .ready
            progress = 1
            return locale
        } catch {
            status = .failed(error.localizedDescription)
            throw error
        }
    }

    private func observe(_ downloadProgress: Progress) {
        observation = downloadProgress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] p, _ in
            let value = p.fractionCompleted
            Task { @MainActor in self?.progress = value }
        }
    }

    private static func pickLocale() async -> Locale? {
        if let match = await DictationTranscriber.supportedLocale(equivalentTo: .current) {
            return match
        }
        return await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US"))
    }
}
