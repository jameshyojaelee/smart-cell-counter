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
public final class PurchaseManager: ObservableObject, PurchaseManaging {
    public static let shared = PurchaseManager()
    private let productId = "com.smartcellcounter.pro"
    @Published public private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: "pro.entitled")
    @Published public private(set) var price: String?
    private var product: Product?

    private init() {}

    public func loadProducts() async {
        do {
            let products = try await Product.products(for: [productId])
            self.product = products.first
            if let p = products.first { self.price = p.displayPrice }
            for await result in Transaction.updates {
                await self.handle(transactionResult: result)
            }
        } catch {
            Logger.log("StoreKit load error: \(error)")
        }
    }

    public func purchase() async throws {
        guard let product else { throw NSError(domain: "IAP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not loaded"]) }
        let result = try await product.purchase()
        await handle(transactionResult: result)
    }

    public func restore() async throws {
        try await AppStore.sync()
        // Entitlement will be updated via Transaction.updates
    }

    private func setEntitled(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "pro.entitled")
    }

    private func handle(transactionResult: Product.PurchaseResult) async {
        switch transactionResult {
        case .success(let verification):
            do {
                let transaction = try self.checkVerified(verification)
                if transaction.productID == productId {
                    setEntitled(true)
                }
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

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "IAP", code: -2, userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"])
        case .verified(let safe):
            return safe
        }
    }
}
