import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var isPracticing = false
    @State private var showPaywall = false

    private var targetsBySound: [(String, Int)] {
        var counts: [String: Int] = [:]
        for t in store.state.targets { counts[t.sound, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    header

                    if store.streakDays > 0 {
                        streakCard
                    }

                    startCard

                    if !store.state.attempts.isEmpty {
                        recentCard
                    }

                    if !store.state.isUnlocked {
                        freeTierNote
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Practice")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.ink)
                }
            }
            .fullScreenCover(isPresented: $isPracticing) {
                PracticeView { isPracticing = false }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DS.ink)
            Text(store.state.child.name.isEmpty
                 ? "Ready when you are."
                 : "\(store.state.child.name) · \(store.state.targets.count) words in rotation")
                .font(.system(size: 15))
                .foregroundStyle(DS.inkMuted)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var streakCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18))
                .foregroundStyle(DS.close)
            Text("\(store.streakDays) day\(store.streakDays == 1 ? "" : "s") in a row")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.ink)
            Spacer()
            Text("\(store.todayAttempts.count) today")
                .font(.system(size: 13))
                .foregroundStyle(DS.inkMuted)
        }
        .card(padding: 14)
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's set")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.inkMuted)
                .textCase(.uppercase)
                .kerning(0.6)

            HStack(spacing: 8) {
                ForEach(Array(targetsBySound.prefix(4).enumerated()), id: \.offset) { item in
                    Text("/\(item.element.0)/")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(DS.accentSoft)
                        .clipShape(Capsule())
                }
                if targetsBySound.count > 4 {
                    Text("+\(targetsBySound.count - 4)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.inkMuted)
                }
            }

            Button {
                if store.needsUnlock {
                    showPaywall = true
                } else {
                    isPracticing = true
                }
            } label: {
                Text("Start 5 minutes")
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("\(min(10, store.state.targets.count)) words · about 4 minutes")
                .font(.system(size: 12))
                .foregroundStyle(DS.inkMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .card()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last 7 days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.inkMuted)
                    .textCase(.uppercase)
                    .kerning(0.6)
                Spacer()
                NavigationLink("Report") { ReportView() }
                    .font(.system(size: 13, weight: .semibold))
            }

            let stats = store.report(days: 7)
            HStack(spacing: 0) {
                statBlock(value: "\(stats.totalSessions)", label: "sessions")
                divider
                statBlock(value: "\(Int((stats.accuracy * 100).rounded()))%", label: "correct")
                divider
                statBlock(value: "\(stats.distinctPracticeDays)", label: "days")
            }
        }
        .card()
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.hairline)
            .frame(width: 1, height: 34)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DS.ink)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DS.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var freeTierNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.open")
                .font(.system(size: 14))
                .foregroundStyle(DS.accent)
            Text(store.sessionsRemainingFree > 0
                 ? "\(store.sessionsRemainingFree) free sessions left. Then \(purchases.displayPrice) once, forever."
                 : "Unlock unlimited sessions and PDF reports for \(purchases.displayPrice) once.")
                .font(.system(size: 13))
                .foregroundStyle(DS.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .card(padding: 14)
    }
}
