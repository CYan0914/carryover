import SwiftUI

@main
struct CarryoverApp: App {

    @StateObject private var store: AppStore = {
        #if DEBUG
        if DemoFlags.isDemo {
            // Onboarding is the empty state, so it gets an empty fixture.
            return AppStore(demo: DemoFlags.showsOnboarding ? AppState() : DemoMode.state())
        }
        #endif
        return AppStore()
    }()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(purchases)
                .tint(DS.accent)
                .preferredColorScheme(.light)
                .task {
                    // Both calls are capped inside PurchaseManager, so this
                    // task cannot outlive the first screen for long. Running
                    // them together keeps the launch path to one timeout
                    // instead of two.
                    async let loading: Void = purchases.loadProduct()
                    if await purchases.refreshEntitlement() {
                        store.setUnlocked(true)
                    }
                    await loading
                }
        }
    }
}
