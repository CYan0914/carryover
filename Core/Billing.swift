import Foundation

/// Non-isolated constants.
///
/// They live outside `AppStore` on purpose: the store is `@MainActor`, which
/// makes its static members isolated too, and reading one from another
/// MainActor type's property initialiser is the kind of thing that compiles
/// today and stops compiling at the next Swift language mode.
enum Billing {
    /// Must match the product created in App Store Connect exactly. A typo
    /// here does not fail loudly — `Product.products(for:)` simply returns an
    /// empty array and the paywall shows the fallback price forever.
    static let unlockProductID = "com.cyan0914.carryover.full"

    /// Sessions available before the unlock prompt. Five is enough to see the
    /// whole loop, including one full week of practice, and short enough that
    /// a family who is going to pay does it while the habit is fresh.
    static let freeSessionLimit = 5
}
