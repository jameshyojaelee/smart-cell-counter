import Foundation

public enum AppError: LocalizedError, Equatable {
    case permissionDenied
    case configurationFailed(String)
    case hardwareUnavailable
    case notReady
    case unknown

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: "Camera permission denied."
        case let .configurationFailed(msg): "Camera configuration failed: \(msg)"
        case .hardwareUnavailable: "Camera unavailable."
        case .notReady: "Camera not ready."
        case .unknown: "Unknown error."
        }
    }
}
