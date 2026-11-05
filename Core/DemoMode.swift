import Foundation

/// Fixture data for App Store screenshots and for looking at a screen quickly
/// on a simulator. Everything here is behind `#if DEBUG`, so nothing in this
/// file compiles into the Release build that ships.
///
/// The reason this exists at all: this project is developed on a machine with
/// no Xcode. The only place the app runs is a GitHub macOS runner, and tapping
/// through onboarding there is not practical. Launch arguments seed the state
/// and pick the screen instead of a scripted tap sequence, which also keeps the
/// screenshots reproducible.
enum DemoFlags {

    static let isDemo: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-CarryoverDemo")
        #else
        return false
        #endif
    }()

    /// One of: onboarding, home, practice, report, paywall.
    static let screen: String = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-CarryoverDemoScreen"), i + 1 < args.count {
            return args[i + 1]
        }
        return "home"
        #else
        return "home"
        #endif
    }()

    static var showsOnboarding: Bool { isDemo && screen == "onboarding" }
    static var initialTab: Int { isDemo && screen == "report" ? 2 : 0 }
    static var opensPractice: Bool { isDemo && screen == "practice" }
    static var opensPaywall: Bool { isDemo && screen == "paywall" }
}

#if DEBUG
enum DemoMode {

    /// Two weeks of a family doing the work, so the streak, the report and the
    /// PDF all have something to show. The numbers are shaped rather than
    /// random: "rabbit" and "rain" are mastered, "world" and "girl" are not,
    /// because a report where everything is 100% is not a realistic screenshot
    /// and would misrepresent what the page looks like in use.
    static func state() -> AppState {
        var s = AppState()
        s.child = ChildProfile(name: "Mia", birthYear: 2019)
        s.isUnlocked = true

        let spec: [(String, String, WordPosition, Double)] = [
            ("rabbit", "r", .initial, 0.92),
            ("rain", "r", .initial, 0.86),
            ("red", "r", .initial, 0.78),
            ("green", "r", .medial, 0.64),
            ("bird", "r", .final, 0.58),
            ("star", "r", .final, 0.47),
            ("world", "r", .medial, 0.26),
            ("girl", "r", .final, 0.18),
        ]

        s.targets = spec.map {
            TargetWord(text: $0.0, sound: $0.1, position: $0.2)
        }

        let cal = Calendar.current
        let now = Date()
        // Sessions on 9 of the last 14 days, skipping a couple so the streak is
        // believable rather than a perfect run.
        let daysBack = [13, 12, 11, 10, 9, 7, 6, 4, 3, 2, 1, 0]

        for back in daysBack {
            guard let day = cal.date(byAdding: .day, value: -back, to: now) else { continue }
            let start = cal.date(bySettingHour: 17, minute: 20, second: 0, of: day) ?? day
            let session = PracticeSession(
                id: UUID(),
                startedAt: start,
                endedAt: start.addingTimeInterval(310),
                wordCount: spec.count,
                targetSound: "r"
            )
            s.sessions.append(session)

            // Later days score better, so the trend has a direction.
            let progress = 1.0 - Double(back) / 20.0

            for (index, item) in spec.enumerated() {
                let target = item.3
                let expected = (target * 0.55) + (target * progress * 0.45)
                let bucket = Double((index + back) % 10) / 10.0
                let result: AttemptResult
                if bucket < expected - 0.1 {
                    result = .correct
                } else if bucket < expected + 0.18 {
                    result = .close
                } else {
                    result = .missed
                }
                s.attempts.append(Attempt(
                    id: UUID(),
                    wordID: s.targets[index].id,
                    wordText: item.0,
                    sound: item.1,
                    position: item.2,
                    result: result,
                    date: start.addingTimeInterval(Double(index) * 34),
                    sessionID: session.id
                ))
            }
        }

        return s
    }
}
#endif
