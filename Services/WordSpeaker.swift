import AVFoundation
import Foundation

/// Speaks the target word so the parent has a model to imitate.
///
/// This is output only. The app never opens the microphone and never asks for
/// speech recognition permission — see the comment on `AttemptResult` for why.
/// Keeping it output-only also means the app cannot be mistaken for a
/// diagnostic tool, which is the single biggest App Store risk in this
/// category.
@MainActor
final class WordSpeaker: ObservableObject {

    private let synthesizer = AVSpeechSynthesizer()

    /// Slightly slower than the default so a two-year-old has time to process
    /// the word. 0.45 is the default rate; 0.42 is perceptibly calmer without
    /// sounding robotic.
    func speak(_ word: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // Drop a trailing "—" used as a placeholder in the library.
        let clean = word.replacingOccurrences(of: "—", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1

        // Audio has to survive the silent switch: a parent practicing with a
        // muted phone should still hear the word. Setting the session category
        // is the supported way to do that without the user changing a setting.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch {
            // Speaking still works without the category; it just respects the
            // mute switch. Never block the practice flow on this.
        }

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
