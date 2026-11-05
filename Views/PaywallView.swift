import SwiftUI

/// The paywall.
///
/// The copy does the heavy lifting here. The whole competitive claim is "we do
/// not do what the others do to you": no subscription, no trial that charges
/// early, no per-child add-on. Every line below is a direct answer to a
/// complaint found in a competitor's one-star reviews.
struct PaywallView: View {
    let onClose: () -> Void

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.inkMuted)
                            .frame(width: 30, height: 30)
                            .background(DS.accentSoft)
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pay once.\nNot every month.")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Speech practice is something you do for months, not forever. "
                         + "So this is a single purchase, not a subscription.")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    row("infinity", "Unlimited practice sessions")
                    row("doc.text", "One-page PDF, ready to hand over")
                    row("lock.shield", "Everything stays on this phone, forever")
                    row("arrow.counterclockwise", "Free to reinstall on any device you own")
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("What other apps do that this one will not")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.inkMuted)
                        .textCase(.uppercase)
                        .kerning(0.6)

                    ForEach(notDoing, id: \.self) { line in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(DS.miss)
                                .padding(.top, 4)
                            Text(line)
                                .font(.system(size: 14))
                                .foregroundStyle(DS.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await buy() }
                    } label: {
                        HStack(spacing: 8) {
                            if purchases.isPurchasing || isWorking {
                                ProgressView().tint(.white)
                            }
                            Text("Unlock for \(purchases.displayPrice)")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(purchases.isPurchasing || isWorking)

                    Text("One-time purchase. No renewal. No account.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.inkMuted)

                    Button("Restore a previous purchase") {
                        Task { await restore() }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(DS.accent)
                    .padding(.top, 4)
                }

                if let error = purchases.errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(DS.miss)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Text("Price shown is set by the App Store for your region and may differ from what is displayed here.")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .background(DS.bg.ignoresSafeArea())
        .task { await purchases.loadProduct() }
    }

    private var notDoing: [String] {
        [
            "No $14.99 a month",
            "No free trial that charges you before it ends",
            "No per-child or per-sound add-ons",
            "No advertising, no analytics SDK, no data sale",
            "No account to create, and nothing to forget the password to"
        ]
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(DS.accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func buy() async {
        isWorking = true
        let ok = await purchases.purchase()
        isWorking = false
        if ok {
            store.setUnlocked(true)
            onClose()
        }
    }

    private func restore() async {
        isWorking = true
        let ok = await purchases.refreshEntitlement()
        isWorking = false
        if ok {
            store.setUnlocked(true)
            onClose()
        } else {
            purchases.errorMessage = "No previous purchase found on this Apple ID."
        }
    }
}
