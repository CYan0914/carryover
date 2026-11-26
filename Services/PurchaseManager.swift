import Foundation
import StoreKit
import SwiftUI
import RevenueCat

/// One non-consumable unlock. No subscription.
///
/// The product decision is unchanged: pay once, no trial that charges early,
/// no per-child add-on. RevenueCat sits in front of StoreKit so sales and new
/// installs are visible in its dashboard. It does not change what the customer
/// buys or what they see on the paywall.
@MainActor
final class PurchaseManager: ObservableObject {

    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    /// False until the first entitlement check has come back. The UI uses this
    /// to avoid rendering "Not unlocked" for a second and then silently
    /// flipping to "Unlocked" once the answer arrives.
    @Published private(set) var entitlementChecked = false

    private let productID = Billing.unlockProductID

    /// RevenueCat is only configured when a real key was baked into the build.
    /// Local builds and the screenshot job leave it empty and keep the direct
    /// StoreKit 2 path, so a demo run never creates a fake customer in RC.
    private let useRevenueCat: Bool

    /// For RC purchases and for the price shown on the paywall. Published so
    /// the paywall price updates once offerings come back.
    @Published private(set) var package: Package?

    /// The in-flight load, shared between the launch call and the paywall's
    /// `.task`. StoreKit serialises product requests internally, so two
    /// concurrent calls can make the second wait for the first one's round trip.
    private var loadTask: Task<Product?, Never>?

    /// Neither StoreKit nor RC offers a timeout. On a bad connection either can
    /// sit with no error, which leaves the paywall button spinning forever.
    private static let timeout: Double = 8

    private struct LoadedProduct {
        let product: Product?
        let package: Package?
    }

    init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Xcode leaves the literal $(REVENUECAT_API_KEY) in place when the
        // build setting is empty. Treat that as "not configured".
        let configured = !key.isEmpty && !key.hasPrefix("$(")
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        if configured {
            Purchases.configure(withAPIKey: key)
        }
        useRevenueCat = configured
    }

    func loadProduct() async {
        if product != nil { return }
        if let existing = loadTask {
            product = await existing.value
            return
        }
        let id = productID
        let useRC = useRevenueCat
        let task = Task<Product?, Never> {
            // Deliberately quiet on failure. Before the product exists in App
            // Store Connect the request returns empty with no error at all.
            // Only an explicit purchase attempt reports a problem.
            let loaded = await withTimeout(seconds: Self.timeout) { () -> LoadedProduct? in
                if useRC {
                    let offerings = try? await Purchases.shared.offerings()
                    let found = offerings?.current?.availablePackages.first {
                        $0.storeProduct.productIdentifier == id
                    } ?? offerings?.current?.availablePackages.first
                    // RC exposes StoreKit 1 SKProduct here; keep it in the
                    // RC package and read the price from storeProduct instead.
                    return LoadedProduct(product: nil, package: found)
                }
                return LoadedProduct(
                    product: (try? await Product.products(for: [id]))?.first,
                    package: nil
                )
            }
            package = loaded?.package
            return loaded?.product ?? nil
        }
        loadTask = task
        product = await task.value
        loadTask = nil
    }

    var displayPrice: String {
        package?.storeProduct.localizedPriceString
            ?? product?.displayPrice
            ?? "$3.99"
    }

    /// Returns true when the unlock is now active.
    func purchase() async -> Bool {
        if useRevenueCat {
            if package == nil { await loadProduct() }
            guard let package else {
                errorMessage = "The App Store is unavailable right now."
                return false
            }
            return await buy(package)
        }
        if product == nil { await loadProduct() }
        guard let product else {
            errorMessage = "The App Store is unavailable right now."
            return false
        }
        return await finish(product)
    }

    private func buy(_ package: Package) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            // No timeout here on purpose: the system purchase sheet waits for
            // the customer. Cutting it off mid-sheet would be worse than a slow
            // network.
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            return isUnlocked(in: result.customerInfo)
        } catch {
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    private func finish(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return true
                case .unverified:
                    errorMessage = "That purchase could not be verified."
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "Your purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    /// Re-check entitlements at launch. A timeout answers `false`, which the
    /// caller must read as "not proven unlocked" rather than "proven locked" —
    /// it never revokes an unlock already on disk.
    func refreshEntitlement() async -> Bool {
        let id = productID
        let useRC = useRevenueCat
        let found = await withTimeout(seconds: Self.timeout) { () -> Bool in
            if useRC {
                let info = try? await Purchases.shared.customerInfo()
                return info.map { isUnlocked(in: $0) } ?? false
            }
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID == id,
                   transaction.revocationDate == nil {
                    return true
                }
            }
            return false
        }
        entitlementChecked = true
        return found ?? false
    }

    /// The Restore button must force RC to re-fetch receipts. Calling
    /// `customerInfo()` alone can return a cached answer.
    func restore() async -> Bool {
        guard useRevenueCat else { return await refreshEntitlement() }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            entitlementChecked = true
            return isUnlocked(in: info)
        } catch {
            errorMessage = "Restore failed. Please try again."
            entitlementChecked = true
            return false
        }
    }

}

/// Free function, not a static member: the class is @MainActor, but this is
/// called from a @Sendable timeout closure.
private func isUnlocked(in info: CustomerInfo) -> Bool {
    info.entitlements[Billing.entitlementID]?.isActive == true
}

/// Race an operation against a deadline.
///
/// Returns nil when the deadline wins, and cancels the loser so a hung call
/// does not keep running in the background.
///
/// Deliberately not a `withTaskGroup` race. A task group waits for every child
/// before it returns, and cancellation is cooperative: a child sitting inside
/// a network call that ignores the cancellation flag would keep the group open
/// past the deadline. So the operation runs unstructured and whichever finishes
/// first resumes the continuation.
private func withTimeout<T>(
    seconds: Double,
    _ operation: @escaping @Sendable () async -> T?
) async -> T? {
    await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        let box = ResumeOnce(continuation)
        let work = Task {
            box.resume(with: await operation())
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if box.resume(with: nil) {
                work.cancel()
            }
        }
    }
}

/// Lets exactly one of the two racing tasks win. Without this, a slow operation
/// finishing just after the deadline would resume the same continuation twice
/// and trap.
private final class ResumeOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) {
        self.continuation = continuation
    }

    /// Returns true when this call was the one that resumed the continuation.
    @discardableResult
    func resume(with value: T?) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        pending.resume(returning: value)
        return true
    }
}
