import Foundation
import Combine
import Speech
import AVFoundation

/// Apple Speech STT + on-device speech playback. Not a Siri private API.
@MainActor
final class VoiceService: NSObject, ObservableObject {
    @Published var lastTranscript = ""
    @Published var speechAvailable = false
    @Published var onDeviceAvailable = false
    @Published var status = "Not authorized"

    private let synthesizer = AVSpeechSynthesizer()
    private let locale = Locale(identifier: "zh-CN")

    func requestAuthorization() async -> Bool {
        let authorization: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { result in
                continuation.resume(returning: result)
            }
        }
        let recognizer = SFSpeechRecognizer(locale: locale)
        onDeviceAvailable = recognizer?.supportsOnDeviceRecognition ?? false
        speechAvailable = authorization == .authorized && recognizer != nil
        status = speechAvailable ? (onDeviceAvailable ? "Chinese on-device available" : "Chinese recognition requires network") : "Speech permission denied or unavailable"
        return speechAvailable
    }

    func transcribe(wavData: Data, requireOffline: Bool = false) async throws -> String {
        guard await requestAuthorization() else { throw VoiceError.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw VoiceError.unavailable
        }
        if requireOffline && !recognizer.supportsOnDeviceRecognition {
            throw VoiceError.offlineUnavailable
        }
        guard wavData.count > 44 && wavData.count <= 8_000_000 else { throw VoiceError.invalidAudio }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try wavData.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = requireOffline
        let recognized = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            var resolved = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !resolved else { return }
                if let error {
                    resolved = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    resolved = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
            _ = task
        }
        lastTranscript = recognized
        return recognized
    }

    func speakChinese(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}

enum VoiceError: LocalizedError {
    case notAuthorized, unavailable, offlineUnavailable, invalidAudio
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition permission is not granted"
        case .unavailable: return "Chinese speech recognition is unavailable"
        case .offlineUnavailable: return "Chinese on-device recognition is not supported by this iPhone"
        case .invalidAudio: return "Provide a valid WAV file up to 8 MB"
        }
    }
}
