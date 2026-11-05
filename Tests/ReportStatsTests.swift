import XCTest
@testable import Carryover

/// The report numbers are the only part of this app that a clinician reads, and
/// they are pure functions, so they get tests. Everything else is UI.
final class ReportStatsTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    private func attempt(_ word: String, _ result: AttemptResult, daysAgo: Int,
                         sound: String = "r", session: UUID = UUID()) -> Attempt {
        Attempt(wordID: UUID(), wordText: word, sound: sound,
                position: .initial, result: result, date: date(daysAgo: daysAgo),
                sessionID: session)
    }

    private func session(daysAgo: Int, words: Int = 10) -> PracticeSession {
        PracticeSession(startedAt: date(daysAgo: daysAgo),
                        endedAt: date(daysAgo: daysAgo).addingTimeInterval(240),
                        wordCount: words, targetSound: "r")
    }

    func testAccuracyCountsOnlyCorrect() {
        let attempts = [
            attempt("rabbit", .correct, daysAgo: 1),
            attempt("rabbit", .close, daysAgo: 1),
            attempt("rabbit", .missed, daysAgo: 2),
            attempt("rabbit", .missed, daysAgo: 2)
        ]
        let stats = ReportStats.build(attempts: attempts, sessions: [], from: date(daysAgo: 7), to: Date())

        XCTAssertEqual(stats.totalAttempts, 4)
        XCTAssertEqual(stats.correctCount, 1)
        XCTAssertEqual(stats.closeCount, 1)
        XCTAssertEqual(stats.accuracy, 0.25, accuracy: 0.0001)
    }

    func testCloseCountsAsHalfForWeightedAccuracy() {
        let attempts = [
            attempt("rabbit", .correct, daysAgo: 1),
            attempt("rabbit", .close, daysAgo: 1)
        ]
        let stats = ReportStats.build(attempts: attempts, sessions: [], from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.weightedAccuracy, 0.75, accuracy: 0.0001)
    }

    func testAttemptsOutsideWindowAreExcluded() {
        let attempts = [
            attempt("rabbit", .correct, daysAgo: 1),
            attempt("rabbit", .missed, daysAgo: 40)
        ]
        let stats = ReportStats.build(attempts: attempts, sessions: [], from: date(daysAgo: 30), to: Date())
        XCTAssertEqual(stats.totalAttempts, 1)
        XCTAssertEqual(stats.missedCount, 0)
    }

    func testStruggledRequiresAtLeastTwoAttempts() {
        let attempts = [
            attempt("star", .missed, daysAgo: 1),
            attempt("car", .missed, daysAgo: 1),
            attempt("car", .missed, daysAgo: 2)
        ]
        let stats = ReportStats.build(attempts: attempts, sessions: [], from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.struggled.map(\.text), ["car"])
    }

    func testMasteredRequiresThreeAttemptsAndEightyPercent() {
        let attempts = [
            attempt("red", .correct, daysAgo: 1),
            attempt("red", .correct, daysAgo: 1),
            attempt("red", .correct, daysAgo: 2),
            // 4 of 5 = exactly 80%, which must pass the threshold.
            attempt("ring", .correct, daysAgo: 1),
            attempt("ring", .correct, daysAgo: 1),
            attempt("ring", .correct, daysAgo: 2),
            attempt("ring", .correct, daysAgo: 2),
            attempt("ring", .missed, daysAgo: 2),
            // 3 of 5 = 60%, which must not.
            attempt("rope", .correct, daysAgo: 1),
            attempt("rope", .correct, daysAgo: 1),
            attempt("rope", .correct, daysAgo: 2),
            attempt("rope", .missed, daysAgo: 2),
            attempt("rope", .missed, daysAgo: 2)
        ]
        let stats = ReportStats.build(attempts: attempts, sessions: [], from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.mastered.map(\.text).sorted(), ["red", "ring"])
    }

    func testDistinctPracticeDaysCollapsesSameDaySessions() {
        let sessions = [session(daysAgo: 0), session(daysAgo: 0), session(daysAgo: 1)]
        let stats = ReportStats.build(attempts: [], sessions: sessions,
                                      from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.totalSessions, 3)
        XCTAssertEqual(stats.distinctPracticeDays, 2)
    }

    func testSessionsPerWeekOnASevenDayWindow() {
        let sessions = [session(daysAgo: 0), session(daysAgo: 2), session(daysAgo: 4)]
        let stats = ReportStats.build(attempts: [], sessions: sessions,
                                      from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.sessionsPerWeek, 3.0, accuracy: 0.001)
    }

    func testEmptyStatsDoNotDivideByZero() {
        let stats = ReportStats.build(attempts: [], sessions: [], from: date(daysAgo: 7), to: Date())
        XCTAssertEqual(stats.accuracy, 0)
        XCTAssertEqual(stats.weightedAccuracy, 0)
        XCTAssertTrue(stats.rows.isEmpty)
        XCTAssertTrue(stats.struggled.isEmpty)
    }
}

final class WordLibraryTests: XCTestCase {

    func testEverySoundExposesAtLeastInitialPosition() {
        for group in WordLibrary.groups {
            XCTAssertFalse(WordLibrary.words(for: group.sound, position: .initial).isEmpty,
                           "\(group.sound) has no initial words")
        }
    }

    func testPlaceholderIsFilteredOut() {
        // "r-blends" has no final-position words and stores "—" as a
        // placeholder rather than an empty array.
        let finals = WordLibrary.words(for: "r-blends", position: .final)
        XCTAssertFalse(finals.contains("—"))
    }

    func testUnknownSoundReturnsEmpty() {
        XCTAssertTrue(WordLibrary.words(for: "zzz", position: .initial).isEmpty)
    }
}
