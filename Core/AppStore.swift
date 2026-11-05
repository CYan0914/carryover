import Foundation
import Combine

/// Single source of truth for the app's data.
///
/// Storage is one JSON file in Application Support, read once at launch and
/// written back on every mutation. There is no database and no server. That is
/// a product decision, not a shortcut: this data is a child's health records,
/// and the simplest way to guarantee it is never sold, leaked, or lost to a
/// backend outage is to not send it anywhere.
///
/// The tradeoff is that a family with two phones gets two separate histories.
/// That is the right trade for now — the plan is a local file export/import,
/// not an account system.
@MainActor
final class AppStore: ObservableObject {

    @Published private(set) var state: AppState

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        let url = fileURL ?? AppStore.defaultFileURL()
        self.fileURL = url

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec

        if let data = try? Data(contentsOf: url),
           let loaded = try? dec.decode(AppState.self, from: data) {
            self.state = loaded
        } else {
            self.state = AppState()
        }
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Carryover", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    // MARK: - Derived

    var hasTargets: Bool { !state.targets.isEmpty }

    var needsUnlock: Bool {
        !state.isUnlocked && state.sessions.count >= Billing.freeSessionLimit
    }

    var sessionsRemainingFree: Int {
        max(0, Billing.freeSessionLimit - state.sessions.count)
    }

    var todayAttempts: [Attempt] {
        let start = Calendar.current.startOfDay(for: Date())
        return state.attempts.filter { $0.date >= start }
    }

    var streakDays: Int {
        let cal = Calendar.current
        let days = Set(state.sessions.map { cal.startOfDay(for: $0.startedAt) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        // A streak that has not been extended today is still alive if it ran
        // through yesterday; only break it once a full day is skipped.
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: - Mutations

    func setChildName(_ name: String) {
        state.child.name = name
        persist()
    }

    func setBirthYear(_ year: Int?) {
        state.child.birthYear = year
        persist()
    }

    func addTarget(_ word: TargetWord) {
        let exists = state.targets.contains {
            $0.text.caseInsensitiveCompare(word.text) == .orderedSame && $0.sound == word.sound
        }
        guard !exists else { return }
        state.targets.append(word)
        persist()
    }

    func addTargets(_ words: [TargetWord]) {
        for w in words { addTarget(w) }
    }

    func removeTarget(id: UUID) {
        state.targets.removeAll { $0.id == id }
        persist()
    }

    func removeTargets(forSound sound: String) {
        state.targets.removeAll { $0.sound == sound }
        persist()
    }

    func record(_ attempts: [Attempt], session: PracticeSession) {
        state.attempts.append(contentsOf: attempts)
        state.sessions.append(session)
        persist()
    }

    func setUnlocked(_ unlocked: Bool) {
        state.isUnlocked = unlocked
        persist()
    }

    func deleteEverything() {
        state = AppState()
        persist(immediately: true)
    }

    // MARK: - Report

    func report(days: Int) -> ReportStats {
        let cal = Calendar.current
        let to = Date()
        let from = cal.date(byAdding: .day, value: -days, to: to) ?? to
        return ReportStats.build(attempts: state.attempts, sessions: state.sessions, from: from, to: to)
    }

    // MARK: - Export / import

    func exportJSON() -> URL? {
        guard let data = try? encoder.encode(state) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("carryover-backup-\(stamp).json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    /// Writes are coalesced: a practice session records a dozen attempts in a
    /// row and each one is a separate tap, so saving synchronously on every tap
    /// would do a full file write per button press on a device that may be
    /// running on low power. Debouncing keeps the last state only.
    private func persist(immediately: Bool = false) {
        saveTask?.cancel()
        if immediately {
            write()
            return
        }
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
