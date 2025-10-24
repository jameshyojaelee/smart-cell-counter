import Foundation

public enum AppError: LocalizedError, Equatable {
    case permissionDenied
    case configurationFailed(String)
    case hardwareUnavailable
    case notReady
    case unknown

    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Camera permission denied."
        case .configurationFailed(let msg): return "Camera configuration failed: \(msg)"
        case .hardwareUnavailable: return "Camera unavailable."
        case .notReady: return "Camera not ready."
        case .unknown: return "Unknown error."
        }
    }
}
