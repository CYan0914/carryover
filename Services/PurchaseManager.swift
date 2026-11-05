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

    private let productID = Billing.unlockProductID

    func loadProduct() async {
        // Deliberately quiet on failure. This runs at launch, and before the
        // product exists in App Store Connect `Product.products(for:)` returns
        // an empty array with no error at all — surfacing that as "could not
        // reach the App Store" would accuse the network of a setup mistake.
        // Only an explicit purchase attempt reports an error.
        if let products = try? await Product.products(for: [productID]) {
            product = products.first
        }
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
    func refreshEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
