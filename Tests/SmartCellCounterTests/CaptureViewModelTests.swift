import XCTest
import Combine
import CoreGraphics
import SwiftUI
@testable import SmartCellCounter

@MainActor
final class CaptureViewModelTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func testPermissionDeniedFlow() {
        let fake = FakeCameraService(permissionGranted: false)
        let vm = CaptureViewModel(service: fake)
        vm.permissionDenied = false

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
        vm.permissionDenied = false

        let readyExp = expectation(description: "View model is ready")
        vm.$ready
            .dropFirst()
            .filter { $0 }
            .first()
            .sink { _ in readyExp.fulfill() }
            .store(in: &cancellables)

        let captureExp = expectation(description: "Capture publishes image")
        vm.captured.sink { _ in captureExp.fulfill() }.store(in: &cancellables)

        vm.start()
        wait(for: [readyExp], timeout: 1.0)
        XCTAssertTrue(vm.ready)

        fake.capturePhoto()
        wait(for: [captureExp], timeout: 1.0)
    }

    func testTorchStatePropagatesToService() {
        let fake = FakeCameraService(permissionGranted: true, readyImmediately: true)
        let vm = CaptureViewModel(service: fake)
        vm.permissionDenied = false

        vm.setTorch(enabled: true)
        XCTAssertEqual(fake.torchEnabledHistory, [true])
        XCTAssertTrue(vm.torchOn)

        vm.setTorch(enabled: false)
        XCTAssertEqual(fake.torchEnabledHistory, [true, false])
        XCTAssertFalse(vm.torchOn)
    }

    func testFocusDelegatesToCameraService() {
        let fake = FakeCameraService(permissionGranted: true, readyImmediately: true)
        let vm = CaptureViewModel(service: fake)
        vm.permissionDenied = false
        vm.focus(at: CGPoint(x: 0.25, y: 0.75))
        XCTAssertEqual(fake.focusPoints.last, CGPoint(x: 0.25, y: 0.75))
    }

    func testScenePhaseBackgroundStopsSession() {
        let fake = FakeCameraService(permissionGranted: true, readyImmediately: true)
        let vm = CaptureViewModel(service: fake)
        vm.permissionDenied = false
        vm.start()
        XCTAssertEqual(fake.startCount, 1)
        vm.handleScenePhase(.background)
        XCTAssertEqual(fake.stopCount, 1)
    }
}
