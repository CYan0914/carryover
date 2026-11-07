import Foundation
import StoreKit
import SwiftUI

/// One non-consumable unlock. No subscription.
///
/// This is the product decision that the entire positioning rests on. The
/// category leader charges $14.99/month and 59 of its 85 recent one-star
/// reviews are about billing. The second-most popular articulation app
/// converted a $60 one-time purchase into a subscription and its reviews
/// turned on it ("it should be illegal to charge over $60 for an app years ago
/// and then discontinue that app"). Charging once is both the ethical answer
/// and the marketing wedge.
@MainActor
final class PurchaseManager: ObservableObject {

    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    /// False until the first entitlement check has come back. The UI uses this
    /// to avoid rendering "Not unlocked" for a second and then silently
    /// flipping to "Unlocked" once StoreKit answers.
    @Published private(set) var entitlementChecked = false

    private let productID = Billing.unlockProductID

    /// The in-flight load, so the launch call and the paywall's `.task` share
    /// one request instead of queueing behind each other. StoreKit serialises
    /// product requests internally, so two concurrent calls can make the
    /// second one wait for the first one's network round trip.
    private var loadTask: Task<Product?, Never>?

    /// StoreKit has no timeout of its own. On a bad connection
    /// `Product.products(for:)` can sit for a long time with no error, which
    /// leaves the paywall button spinning forever. Cap every call.
    private static let timeout: Double = 8

    func loadProduct() async {
        // Deliberately quiet on failure. This runs at launch, and before the
        // product exists in App Store Connect `Product.products(for:)` returns
        // an empty array with no error at all — surfacing that as "could not
        // reach the App Store" would accuse the network of a setup mistake.
        // Only an explicit purchase attempt reports an error.
        if product != nil { return }
        if let existing = loadTask {
            product = await existing.value
            return
        }
        let id = productID
        let task = Task<Product?, Never> {
            await withTimeout(seconds: PurchaseManager.timeout) {
                (try? await Product.products(for: [id]))?.first
            }
        }
        loadTask = task
        product = await task.value
        loadTask = nil
    }

    var displayPrice: String {
        product?.displayPrice ?? "$3.99"
    }

    /// Returns true when the unlock is now active.
    func purchase() async -> Bool {
        guard let product else {
            await loadProduct()
            guard let product else {
                errorMessage = "The App Store is unavailable right now."
                return false
            }
            return await finish(product)
        }
        return await finish(product)
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

    /// Re-check entitlements. Runs at launch and after returning from the
    /// background so a reinstall restores the unlock without a Restore button
    /// tap. StoreKit emits pending transactions for non-consumables on its own,
    /// so this is only the launch path.
    ///
    /// A timeout answers `false`, which the caller must read as "not proven
    /// unlocked" rather than "proven locked" — it never revokes an unlock that
    /// is already on disk.
    func refreshEntitlement() async -> Bool {
        let id = productID
        let found = await withTimeout(seconds: PurchaseManager.timeout) {
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
}

/// Race an operation against a deadline.
///
/// Returns nil when the deadline wins, and cancels the loser so a hung
/// StoreKit call does not keep running in the background.
///
/// Deliberately not a `withTaskGroup` race. A task group waits for every child
/// before it returns, and cancellation is cooperative: a child sitting inside
/// `Product.products(for:)` that ignores the cancellation flag would keep the
/// group open past the deadline. That turns "cap the wait at eight seconds"
/// into "cap nothing", which is exactly the hang this is here to stop. So the
/// operation runs unstructured and whichever finishes first resumes the
/// continuation; the other one's result is dropped.
private func withTimeout<T: Sendable>(
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
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
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
