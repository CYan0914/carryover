import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.hasTargets {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .background(DS.bg.ignoresSafeArea())
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Practice", systemImage: "waveform") }

            TargetsView()
                .tabItem { Label("Words", systemImage: "list.bullet") }

            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - First run

/// The whole onboarding is one decision: which sound are we working on.
///
/// No account, no email, no tour. Three competing apps in this category open
/// with a signup wall and get one-star reviews for exactly that ("Before you can
/// explore app and see what features it has it requires you to sign up for an
/// account. Hard pass, purely for data mining.").
struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var showWordPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Spacer(minLength: 28)

                VStack(alignment: .leading, spacing: 12) {
                    Text("The homework,\nactually done.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(DS.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Five minutes a day with the words your therapist already assigned. "
                         + "Then one page of results for your next session.")
                        .font(.system(size: 17))
                        .foregroundStyle(DS.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Child's first name (optional)")
                    TextField("e.g. Sam", text: $name)
                        .font(.system(size: 17))
                        .padding(14)
                        .background(DS.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DS.hairline, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.words)
                }

                VStack(spacing: 10) {
                    Button("Choose the target sound") {
                        store.setChildName(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        showWordPicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("No account. No sign-up. Everything stays on this phone.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    bullet("Built for the words your therapist gave you, not a generic course")
                    bullet("No microphone, no scoring algorithm, no guessing whether your child said it right")
                    bullet("A one-page PDF at the end, formatted to hand over in the waiting room")
                }
                .padding(.top, 6)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
        }
        .background(DS.bg.ignoresSafeArea())
        .sheet(isPresented: $showWordPicker) {
            NavigationStack {
                SoundPickerView(isOnboarding: true)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.accent)
                .padding(.top, 4)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(DS.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
