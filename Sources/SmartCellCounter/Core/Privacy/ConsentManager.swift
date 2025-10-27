import Foundation

#if canImport(AppTrackingTransparency)
    import AppTrackingTransparency
#endif

public enum Privacy {}

public final class ConsentManager {
    public init() {}
    public func requestTrackingIfNeeded() {
        #if canImport(AppTrackingTransparency)
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { _ in }
            }
        #endif
    }
}
