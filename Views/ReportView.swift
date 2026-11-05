import SwiftUI
import UIKit

struct ReportView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var days = 7
    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var isBuilding = false

    private var stats: ReportStats { store.report(days: days) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {

                    rangePicker

                    summaryCard

                    if stats.rows.isEmpty {
                        emptyState
                    } else {
                        perWordCard
                    }

                    if !stats.struggled.isEmpty {
                        focusCard
                    }

                    exportButton

                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView { showPaywall = false }
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach([7, 30, 90], id: \.self) { d in
                Button {
                    days = d
                } label: {
                    Text(d == 7 ? "7 days" : d == 30 ? "30 days" : "90 days")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(days == d ? .white : DS.inkMuted)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(days == d ? DS.accent : DS.card)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(days == d ? Color.clear : DS.hairline, lineWidth: 1)
                        )
                }
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Between sessions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.inkMuted)
                .textCase(.uppercase)
                .kerning(0.6)

            HStack(spacing: 0) {
                bigStat("\(stats.totalSessions)", "sessions")
                Rectangle().fill(DS.hairline).frame(width: 1, height: 40)
                bigStat("\(Int((stats.accuracy * 100).rounded()))%", "correct")
                Rectangle().fill(DS.hairline).frame(width: 1, height: 40)
                bigStat("\(stats.distinctPracticeDays)", "days")
            }

            Text("\(stats.totalAttempts) productions · \(String(format: "%.1f", stats.sessionsPerWeek)) sessions per week")
                .font(.system(size: 13))
                .foregroundStyle(DS.inkMuted)
        }
        .card()
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(DS.ink)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DS.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var perWordCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Per word")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.inkMuted)
                .textCase(.uppercase)
                .kerning(0.6)
                .padding(.bottom, 12)

            ForEach(stats.rows) { row in
                VStack(spacing: 6) {
                    HStack {
                        Text(row.text)
                            .font(.system(size: 15))
                            .foregroundStyle(DS.ink)
                        Text("/\(row.sound)/")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.inkMuted)
                        Spacer()
                        Text("\(row.attempts)")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.inkMuted)
                        Text("\(Int((row.accuracy * 100).rounded()))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accuracyColor(row.accuracy))
                            .frame(width: 46, alignment: .trailing)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.hairline.opacity(0.55))
                            Capsule()
                                .fill(accuracyColor(row.accuracy))
                                .frame(width: max(3, geo.size.width * row.accuracy))
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.vertical, 9)

                if row.id != stats.rows.last?.id {
                    Rectangle().fill(DS.hairline.opacity(0.5)).frame(height: 0.5)
                }
            }
        }
        .card()
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Below 50% this period")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.inkMuted)
                .textCase(.uppercase)
                .kerning(0.6)

            Text(stats.struggled.prefix(8).map { $0.text }.joined(separator: " · "))
                .font(.system(size: 15))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Shown for reference. Do not change the programme — ask your therapist what to do with these.")
                .font(.system(size: 12))
                .foregroundStyle(DS.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing logged in this window")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.ink)
            Text("Run a practice session and this fills in.")
                .font(.system(size: 13))
                .foregroundStyle(DS.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var exportButton: some View {
        VStack(spacing: 8) {
            Button {
                if store.needsUnlock {
                    showPaywall = true
                } else {
                    buildPDF()
                }
            } label: {
                HStack(spacing: 8) {
                    if isBuilding {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text("One-page PDF for the therapist")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(stats.rows.isEmpty)

            Text("Printed on one page on purpose. Twelve-minute appointments, remember.")
                .font(.system(size: 12))
                .foregroundStyle(DS.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var disclaimer: some View {
        Text("This app records what a parent observed. It does not assess, diagnose, or recommend treatment.")
            .font(.system(size: 11))
            .foregroundStyle(DS.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
    }

    private func accuracyColor(_ value: Double) -> Color {
        if value >= 0.8 { return DS.good }
        if value >= 0.5 { return DS.close }
        return DS.miss
    }

    private func buildPDF() {
        isBuilding = true
        let built = ReportBuilder.makePDF(child: store.state.child, stats: stats, days: days)
        isBuilding = false
        guard let built else { return }
        shareURL = built
        showShare = true
    }
}

/// UIActivityViewController wrapper. SwiftUI has no native share sheet for a
/// file URL, and sharing is the entire delivery mechanism for the report.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
