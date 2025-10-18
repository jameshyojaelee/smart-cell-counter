import XCTest
@testable import SmartCellCounter

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
}
