import XCTest
import Combine
@testable import SmartCellCounter

@MainActor
final class CaptureViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func testPermissionDeniedFlow() {
        let fake = FakeCameraService(permissionGranted: false)
        let vm = CaptureViewModel(service: fake)

        let exp = expectation(description: "Permission denied updates flag")
        vm.$permissionDenied
            .dropFirst()
            .sink { allowed in
                if allowed { exp.fulfill() }
            }
            .store(in: &cancellables)

        vm.start()
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(vm.permissionDenied)
        XCTAssertFalse(vm.ready)
    }

    func testReadyAndCapturePublishesImage() {
        let fake = FakeCameraService(permissionGranted: true, readyImmediately: true)
        let vm = CaptureViewModel(service: fake)

        let captureExp = expectation(description: "Capture publishes image")
        vm.captured.sink { _ in captureExp.fulfill() }.store(in: &cancellables)

        vm.start()
        XCTAssertTrue(vm.ready)

        fake.capturePhoto()
        wait(for: [captureExp], timeout: 1.0)
    }

    func testTorchStatePropagatesToService() {
        let fake = FakeCameraService(permissionGranted: true, readyImmediately: true)
        let vm = CaptureViewModel(service: fake)

        vm.setTorch(enabled: true)
        XCTAssertEqual(fake.torchEnabledHistory, [true])
        XCTAssertTrue(vm.torchOn)

        vm.setTorch(enabled: false)
        XCTAssertEqual(fake.torchEnabledHistory, [true, false])
        XCTAssertFalse(vm.torchOn)
    }
}
