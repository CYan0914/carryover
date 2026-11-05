import Foundation

/// How one production went. Deliberately a human judgement, not a score.
///
/// The app never listens to the child. Every competing app that added
/// automatic speech scoring is buried in one-star reviews about it
/// ("voice recognition not always accurate", "doesn't seem to track actual
/// sounds very well"). A parent standing next to the child is the better
/// judge, and it costs us no microphone permission and no privacy surface.
enum AttemptResult: String, Codable, CaseIterable, Identifiable {
    case correct
    case close
    case missed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .correct: return "Got it"
        case .close: return "Close"
        case .missed: return "Not yet"
        }
    }

    var shortLabel: String {
        switch self {
        case .correct: return "Correct"
        case .close: return "Close"
        case .missed: return "Missed"
        }
    }
}

/// Where the target sound sits inside the word. Speech therapists programme
/// by position, so the report has to speak the same language.
enum WordPosition: String, Codable, CaseIterable, Identifiable {
    case initial
    case medial
    case final

    var id: String { rawValue }

    var label: String {
        switch self {
        case .initial: return "Start"
        case .medial: return "Middle"
        case .final: return "End"
        }
    }
}

struct TargetWord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var sound: String
    var position: WordPosition
    /// True when the family typed this word in from the therapist's handout
    /// rather than picking it from the built-in library.
    var isCustom: Bool = false
}

struct Attempt: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var wordID: UUID
    var wordText: String
    var sound: String
    var position: WordPosition
    var result: AttemptResult
    var date: Date
    var sessionID: UUID
}

struct PracticeSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var startedAt: Date
    var endedAt: Date
    var wordCount: Int
    var targetSound: String

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

struct ChildProfile: Codable, Hashable {
    var name: String = ""
    var birthYear: Int?
}

struct AppState: Codable {
    var child: ChildProfile = ChildProfile()
    var targets: [TargetWord] = []
    var attempts: [Attempt] = []
    var sessions: [PracticeSession] = []
    var isUnlocked: Bool = false
}

// MARK: - Derived statistics

/// Everything the report screen and the PDF are built from. Pure functions on
/// top of the stored attempts so the numbers can be unit tested without a UI.
struct ReportStats {
    struct WordRow: Identifiable {
        var id: String { "\(sound)-\(text)" }
        let text: String
        let sound: String
        let attempts: Int
        let correct: Int
        let close: Int
        let missed: Int

        var accuracy: Double {
            guard attempts > 0 else { return 0 }
            return Double(correct) / Double(attempts)
        }

        /// "Close" counts as half credit for the trend line only. A child
        /// rounding into the right sound is real progress even when it is not
        /// yet a clean production.
        var weightedAccuracy: Double {
            guard attempts > 0 else { return 0 }
            return (Double(correct) + 0.5 * Double(close)) / Double(attempts)
        }
    }

    let from: Date
    let to: Date
    let totalAttempts: Int
    let totalSessions: Int
    let correctCount: Int
    let closeCount: Int
    let missedCount: Int
    let rows: [WordRow]
    let sessionDates: [Date]

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctCount) / Double(totalAttempts)
    }

    var weightedAccuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return (Double(correctCount) + 0.5 * Double(closeCount)) / Double(totalAttempts)
    }

    /// Sessions per week across the reporting window, which is the number a
    /// therapist actually cares about: practice frequency predicts carryover
    /// far more than any single session's score.
    var sessionsPerWeek: Double {
        let days = max(1, Calendar.current.dateComponents([.day], from: from, to: to).day ?? 1)
        return Double(totalSessions) / (Double(days) / 7.0)
    }

    var distinctPracticeDays: Int {
        Set(sessionDates.map { Calendar.current.startOfDay(for: $0) }).count
    }

    /// Words that have never been produced correctly. These are what the next
    /// session should focus on.
    var struggled: [WordRow] {
        rows.filter { $0.attempts >= 2 && $0.accuracy < 0.5 }
            .sorted { $0.accuracy < $1.accuracy }
    }

    var mastered: [WordRow] {
        rows.filter { $0.attempts >= 3 && $0.accuracy >= 0.8 }
            .sorted { $0.accuracy > $1.accuracy }
    }

    static func build(attempts: [Attempt], sessions: [PracticeSession], from: Date, to: Date) -> ReportStats {
        let inWindow = attempts.filter { $0.date >= from && $0.date <= to }
        let sessionsInWindow = sessions.filter { $0.startedAt >= from && $0.startedAt <= to }

        var byWord: [String: [Attempt]] = [:]
        for a in inWindow {
            byWord[a.wordText, default: []].append(a)
        }

        let rows = byWord.map { text, list -> WordRow in
            WordRow(
                text: text,
                sound: list.first?.sound ?? "",
                attempts: list.count,
                correct: list.filter { $0.result == .correct }.count,
                close: list.filter { $0.result == .close }.count,
                missed: list.filter { $0.result == .missed }.count
            )
        }.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }

        return ReportStats(
            from: from,
            to: to,
            totalAttempts: inWindow.count,
            totalSessions: sessionsInWindow.count,
            correctCount: inWindow.filter { $0.result == .correct }.count,
            closeCount: inWindow.filter { $0.result == .close }.count,
            missedCount: inWindow.filter { $0.result == .missed }.count,
            rows: rows,
            sessionDates: sessionsInWindow.map { $0.startedAt }
        )
    }
}
