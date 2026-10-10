import StoreKit

/// In-app purchase layer for the seven chat gifts.
///
/// Gifts are consumables, so a completed purchase is verified on device and
/// then finished immediately. Products are loaded once and cached; the store
/// front end falls back to the published tier price until StoreKit responds.
@MainActor
final class StoreKitService {

    static let shared = StoreKitService()

    enum PurchaseOutcome {
        case purchased
        case cancelled
        case pending
        case unavailable
    }

    enum PurchaseError: LocalizedError {
        case productMissing
        case verificationFailed
        case storeUnreachable

        var errorDescription: String? {
            switch self {
            case .productMissing:     return "This gift is not available right now."
            case .verificationFailed: return "We couldn't verify that purchase."
            case .storeUnreachable:   return "The store is unreachable. Check your connection and try again."
            }
        }
    }

    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private var didStartObserving = false

    private init() {}

    var isReady: Bool { !products.isEmpty }

    func startObservingTransactions() {
        guard !didStartObserving else { return }
        didStartObserving = true
        Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if case let .verified(transaction) = update {
                    await self.deliver(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let identifiers = store.gifts.map(\.productID)
        do {
            let loaded = try await Product.products(for: identifiers)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            products = [:]
        }
    }

    /// The price of the gift as the store has it, or the published tier price
    /// until the products load. The store's own amount is reformatted rather
    /// than shown as `displayPrice`, so a device in another region still reads
    /// dollars and matches the grid.
    func displayPrice(for gift: Gift) -> String {
        if let product = products[gift.productID] {
            return Format.price(product.price)
        }
        return Format.price(gift.price)
    }

    func purchase(_ gift: Gift) async throws -> PurchaseOutcome {
        if products.isEmpty { await loadProducts() }

        guard let product = products[gift.productID] else {
            throw isReady ? PurchaseError.productMissing : PurchaseError.storeUnreachable
        }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await deliver(transaction)
                await transaction.finish()
                return .purchased
            case .unverified:
                throw PurchaseError.verificationFailed
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .unavailable
        }
    }

    func restore() async {
        try? await AppStore.sync()
        for await entitlement in Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement {
                await deliver(transaction)
            }
        }
    }

    private func deliver(_ transaction: Transaction) async {
        guard let gift = store.gifts.first(where: { $0.productID == transaction.productID }) else { return }
        store.grant(gift: gift)
        NotificationCenter.default.post(name: .dancteWallet, object: nil)
    }
}
