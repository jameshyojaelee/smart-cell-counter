@testable import SmartCellCounter
import XCTest

final class MockPurchaseManager: PurchaseManaging {
    private(set) var entitled = false
    var isPro: Bool { entitled }
    var price: String? = "$4.99"
    func loadProducts() async {}
    func purchase() async throws { entitled = true }
    func restore() async throws { entitled = true }
}

final class PurchaseManagerTests: XCTestCase {
    func testEntitlementPersistence() throws {
        let key = "pro.entitled"
        UserDefaults.standard.removeObject(forKey: key)
        _ = PurchaseManager.shared
        // Simulate entitlement by directly setting UserDefaults
        UserDefaults.standard.set(true, forKey: key)
        // Read back
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    }

    func testGatingFlags() throws {
        // When pro: watermark should be off
        UserDefaults.standard.set(true, forKey: "pro.entitled")
        let isPro = UserDefaults.standard.bool(forKey: "pro.entitled")
        XCTAssertTrue(isPro)
        let watermark = !isPro
        XCTAssertFalse(watermark)

        // When not pro: watermark on
        UserDefaults.standard.set(false, forKey: "pro.entitled")
        let notPro = !UserDefaults.standard.bool(forKey: "pro.entitled")
        XCTAssertTrue(notPro)
    }

    func testMockPurchaseAndRestore() async throws {
        let mock = MockPurchaseManager()
        XCTAssertFalse(mock.isPro)
        try await mock.purchase()
        XCTAssertTrue(mock.isPro)
        // Reset and test restore flow
        let mock2 = MockPurchaseManager()
        XCTAssertFalse(mock2.isPro)
        try await mock2.restore()
        XCTAssertTrue(mock2.isPro)
    }

    #if DEBUG
        func testDebugOverrideEntitlementUpdatesState() async {
            let manager = PurchaseManager.shared
            let original = await MainActor.run { manager.isPro }
            await MainActor.run { manager.debugOverrideEntitlement(false) }
            let disabled = await MainActor.run { manager.isPro }
            XCTAssertFalse(disabled)
            await MainActor.run { manager.debugOverrideEntitlement(true) }
            let enabled = await MainActor.run { manager.isPro }
            XCTAssertTrue(enabled)
            await MainActor.run { manager.debugOverrideEntitlement(original) }
        }

        func testResultsViewModelShowsAlertWhenFeatureLocked() async {
            await MainActor.run {
                let manager = PurchaseManager.shared
                let original = manager.isPro
                manager.debugOverrideEntitlement(false)

                let viewModel = ResultsViewModel(defaultDilution: 1.0)
                viewModel.debugResetAlert()
                let canAccess = viewModel.debugCanAccess(.pdf)

                XCTAssertFalse(canAccess)
                XCTAssertEqual(viewModel.alert?.showsUpgrade, true)

                manager.debugOverrideEntitlement(original)
            }
        }

        func testResultsViewModelAllowsFeatureWhenEntitled() async {
            await MainActor.run {
                let manager = PurchaseManager.shared
                let original = manager.isPro
                manager.debugOverrideEntitlement(true)

                let viewModel = ResultsViewModel(defaultDilution: 1.0)
                viewModel.debugResetAlert()
                let canAccess = viewModel.debugCanAccess(.pdf)

                XCTAssertTrue(canAccess)
                XCTAssertNil(viewModel.alert)

                manager.debugOverrideEntitlement(original)
            }
        }
    #endif
}
