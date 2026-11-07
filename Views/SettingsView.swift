import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager

    @State private var nameDraft = ""
    @State private var showDeleteConfirm = false
    @State private var exportURL: URL?
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            List {

                Section("Child") {
                    HStack {
                        Text("First name")
                            .foregroundStyle(DS.ink)
                        Spacer()
                        TextField("Optional", text: $nameDraft)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(DS.inkMuted)
                            .onSubmit { store.setChildName(nameDraft) }
                    }
                    Text("Used only in the PDF header. Nothing is uploaded anywhere.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.inkMuted)
                }

                Section("Unlock") {
                    HStack {
                        Text("Full version")
                        Spacer()
                        if store.state.isUnlocked {
                            Text("Unlocked").foregroundStyle(DS.good)
                        } else if !purchases.entitlementChecked {
                            // StoreKit is still answering. Showing "Not
                            // unlocked" here for a second and then flipping to
                            // "Unlocked" reads as the app granting itself a
                            // purchase.
                            Text("Checking…").foregroundStyle(DS.inkMuted)
                        } else {
                            Text("Not unlocked").foregroundStyle(DS.inkMuted)
                        }
                    }
                    if !store.state.isUnlocked && purchases.entitlementChecked {
                        Button("Unlock for \(purchases.displayPrice)") {
                            Task {
                                if await purchases.purchase() {
                                    store.setUnlocked(true)
                                }
                            }
                        }
                        Button("Restore purchase") {
                            Task {
                                if await purchases.refreshEntitlement() {
                                    store.setUnlocked(true)
                                }
                            }
                        }
                    }
                }

                Section("Your data") {
                    Button {
                        if let url = store.exportJSON() {
                            exportURL = url
                            showShare = true
                        }
                    } label: {
                        Label("Export a backup file", systemImage: "square.and.arrow.up")
                    }

                    HStack {
                        Text("Sessions recorded")
                        Spacer()
                        Text("\(store.state.sessions.count)")
                            .foregroundStyle(DS.inkMuted)
                    }
                    HStack {
                        Text("Productions recorded")
                        Spacer()
                        Text("\(store.state.attempts.count)")
                            .foregroundStyle(DS.inkMuted)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete everything", systemImage: "trash")
                    }
                }

                Section {
                    Text("This app does not use a microphone, does not run speech recognition, and does not send any data off this device. It records what a parent tapped.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.inkMuted)

                    Text("It is not a medical device. It does not diagnose or treat a speech sound disorder. Follow the plan your speech-language pathologist gave you.")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.inkMuted)
                } header: {
                    Text("About")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(DS.inkMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { nameDraft = store.state.child.name }
            .onDisappear { store.setChildName(nameDraft) }
            .confirmationDialog(
                "Delete all practice history?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    store.deleteEverything()
                    nameDraft = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every session, every word, and the unlock stays with your Apple ID. It cannot be undone.")
            }
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
        }
    }
}
