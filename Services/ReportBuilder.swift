import UIKit

/// Builds the one-page PDF a parent hands to their speech therapist.
///
/// This is the whole reason the app exists. A therapist has roughly ten minutes
/// per session and currently gets "we practiced a few times" as the entire
/// home-practice report. One page of frequency and per-word accuracy changes
/// what they can do in that session. Note that everything here is *recorded*,
/// never *interpreted*: no severity score, no percentile, no recommendation.
enum ReportBuilder {

    static func makePDF(child: ChildProfile, stats: ReportStats, days: Int) -> URL? {
        let pageWidth: CGFloat = 612   // US Letter, portrait
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - margin * 2

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-practice-report.pdf")

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Speech Practice Report",
            kCGPDFContextCreator as String: "Carryover"
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                var y = margin

                // ---- Header -------------------------------------------------
                draw("Speech Practice Report",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 30),
                     font: .systemFont(ofSize: 22, weight: .bold),
                     color: UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1))
                y += 30

                let nameLine = child.name.isEmpty ? "Child: —" : "Child: \(child.name)"
                draw(nameLine,
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                     font: .systemFont(ofSize: 12, weight: .medium),
                     color: UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1))
                y += 16

                draw("Reporting window: last \(days) days (\(fmtDate(stats.from)) – \(fmtDate(stats.to)))",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                     font: .systemFont(ofSize: 11, weight: .regular),
                     color: UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1))
                y += 14

                line(from: margin, to: pageWidth - margin, y: y)
                y += 20

                // ---- Summary row -------------------------------------------
                let tileW = (contentWidth - 24) / 3
                let tiles: [(String, String)] = [
                    ("Sessions", "\(stats.totalSessions)"),
                    ("Accuracy", pct(stats.accuracy)),
                    ("Practice days", "\(stats.distinctPracticeDays)")
                ]
                for (i, tile) in tiles.enumerated() {
                    let x = margin + CGFloat(i) * (tileW + 12)
                    let rect = CGRect(x: x, y: y, width: tileW, height: 56)
                    UIColor(red: 0.96, green: 0.98, blue: 0.97, alpha: 1).setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()

                    draw(tile.1,
                         in: CGRect(x: x + 12, y: y + 10, width: tileW - 24, height: 24),
                         font: .systemFont(ofSize: 20, weight: .bold),
                         color: UIColor(red: 0.07, green: 0.42, blue: 0.40, alpha: 1))
                    draw(tile.0,
                         in: CGRect(x: x + 12, y: y + 34, width: tileW - 24, height: 16),
                         font: .systemFont(ofSize: 10, weight: .medium),
                         color: UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1))
                }
                y += 56 + 12

                draw("\(stats.totalAttempts) productions across \(stats.totalSessions) sessions "
                     + "(\(String(format: "%.1f", stats.sessionsPerWeek)) per week).",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                     font: .systemFont(ofSize: 11, weight: .regular),
                     color: UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1))
                y += 28

                // ---- Per-word table ----------------------------------------
                draw("Per-word results",
                     in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                     font: .systemFont(ofSize: 12, weight: .semibold),
                     color: UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1))
                y += 22

                let colWord = margin
                let colSound = margin + 200
                let colN = margin + 268
                let colOK = margin + 318
                let colClose = margin + 368
                let colMiss = margin + 418
                let colPct = margin + 470

                for (label, x) in [("Word", colWord), ("Sound", colSound), ("Tries", colN),
                                   ("Got", colOK), ("Close", colClose), ("Miss", colMiss),
                                   ("Acc.", colPct)] {
                    draw(label,
                         in: CGRect(x: x, y: y, width: 60, height: 14),
                         font: .systemFont(ofSize: 9, weight: .semibold),
                         color: UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1))
                }
                y += 14
                line(from: margin, to: pageWidth - margin, y: y)
                y += 6

                // One page only. If a family practiced more than 22 distinct
                // words the table is truncated rather than spilling to page 2,
                // because a two-page handout does not get read.
                let maxRows = 22
                let shown = Array(stats.rows.prefix(maxRows))
                for row in shown {
                    draw(row.text,
                         in: CGRect(x: colWord, y: y, width: 190, height: 14),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1))
                    draw("/\(row.sound)/",
                         in: CGRect(x: colSound, y: y, width: 60, height: 14),
                         font: .systemFont(ofSize: 9, weight: .regular),
                         color: UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1))
                    draw("\(row.attempts)",
                         in: CGRect(x: colN, y: y, width: 44, height: 14),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1))
                    draw("\(row.correct)",
                         in: CGRect(x: colOK, y: y, width: 44, height: 14),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.16, green: 0.55, blue: 0.36, alpha: 1))
                    draw("\(row.close)",
                         in: CGRect(x: colClose, y: y, width: 44, height: 14),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.75, green: 0.52, blue: 0.10, alpha: 1))
                    draw("\(row.missed)",
                         in: CGRect(x: colMiss, y: y, width: 44, height: 14),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.72, green: 0.28, blue: 0.24, alpha: 1))
                    draw(pct(row.accuracy),
                         in: CGRect(x: colPct, y: y, width: 60, height: 14),
                         font: .systemFont(ofSize: 10, weight: .semibold),
                         color: UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1))
                    y += 16
                }

                if stats.rows.count > maxRows {
                    draw("+ \(stats.rows.count - maxRows) more words in the app.",
                         in: CGRect(x: margin, y: y + 2, width: contentWidth, height: 14),
                         font: .systemFont(ofSize: 9, weight: .regular),
                         color: UIColor(red: 0.5, green: 0.5, blue: 0.52, alpha: 1))
                    y += 18
                }

                // ---- Focus list --------------------------------------------
                if !stats.struggled.isEmpty {
                    y += 12
                    draw("Words that did not reach 50% this period",
                         in: CGRect(x: margin, y: y, width: contentWidth, height: 16),
                         font: .systemFont(ofSize: 11, weight: .semibold),
                         color: UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1))
                    y += 18
                    let list = stats.struggled.prefix(10)
                        .map { "\($0.text) (\(pct($0.accuracy)))" }
                        .joined(separator: "  ·  ")
                    draw(list,
                         in: CGRect(x: margin, y: y, width: contentWidth, height: 34),
                         font: .systemFont(ofSize: 10, weight: .regular),
                         color: UIColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1))
                }

                // ---- Footer ------------------------------------------------
                let footerY = pageHeight - margin - 26
                line(from: margin, to: pageWidth - margin, y: footerY - 8)
                draw("Logged by a parent between sessions. This is a record of what was practiced, "
                     + "not an assessment, diagnosis, or treatment recommendation.",
                     in: CGRect(x: margin, y: footerY, width: contentWidth, height: 24),
                     font: .systemFont(ofSize: 8, weight: .regular),
                     color: UIColor(red: 0.52, green: 0.52, blue: 0.54, alpha: 1))
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Drawing helpers

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.lineSpacing = 2
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ],
            context: nil
        )
    }

    private static func line(from x1: CGFloat, to x2: CGFloat, y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x1, y: y))
        path.addLine(to: CGPoint(x: x2, y: y))
        path.lineWidth = 0.5
        UIColor(red: 0.86, green: 0.86, blue: 0.84, alpha: 1).setStroke()
        path.stroke()
    }

    private static func pct(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static func fmtDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
