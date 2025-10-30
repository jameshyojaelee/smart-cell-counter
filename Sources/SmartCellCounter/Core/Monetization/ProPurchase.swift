import Foundation
import StoreKit

public enum Monetization {}

public protocol PurchaseManaging: AnyObject {
    var isPro: Bool { get }
    var price: String? { get }
    func loadProducts() async
    func purchase() async throws
    func restore() async throws
}

@MainActor
public final class PurchaseManager: ObservableObject, @preconcurrency PurchaseManaging {
    public static let shared = PurchaseManager()
    private let productId = "com.smartcellcounter.pro"
    @Published public private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: "pro.entitled")
    @Published public private(set) var price: String?
    private var product: Product?
    private var updatesTask: Task<Void, Never>?

    private init() {}

    deinit {
        updatesTask?.cancel()
    }

    public func loadProducts() async {
        do {
            let products = try await Product.products(for: [productId])
            product = products.first
            if let p = products.first { price = p.displayPrice }
            startListeningForTransactions()
            await refreshEntitlements()
        } catch {
            Logger.log("StoreKit load error: \(error)")
        }
    }

    public func purchase() async throws {
        guard let product else { throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not loaded"]) }
        let result = try await product.purchase()
        await handlePurchaseResult(result)
        await refreshEntitlements()
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    public func refreshEntitlements() async {
        do {
            if let latest = await Transaction.latest(for: productId) {
                let transaction = try checkVerified(latest)
                apply(transaction: transaction)
            } else {
                setEntitled(false)
            }
        } catch {
            Logger.log("Entitlement refresh failed: \(error)")
        }
    }

    private func setEntitled(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "pro.entitled")
    }

    private func handlePurchaseResult(_ result: Product.PurchaseResult) async {
        switch result {
        case let .success(verification):
            do {
                let transaction = try checkVerified(verification)
                apply(transaction: transaction)
                await transaction.finish()
            } catch { Logger.log("Verification failed: \(error)") }
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    private func handle(transactionUpdate: VerificationResult<Transaction>) async {
        do {
            let transaction: Transaction = try checkVerified(transactionUpdate)
            apply(transaction: transaction)
            await transaction.finish()
        } catch { Logger.log("Update verification failed: \(error)") }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: -2, userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"])
        case let .verified(safe):
            return safe
        }
    }

    private func apply(transaction: Transaction) {
        guard transaction.productID == productId else { return }
        let entitled = transaction.revocationDate == nil
        setEntitled(entitled)
    }

    private func startListeningForTransactions() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                await self.handle(transactionUpdate: update)
            }
        }
    }

    #if DEBUG
        public func debugOverrideEntitlement(_ value: Bool) {
            setEntitled(value)
        }
    #endif
}
