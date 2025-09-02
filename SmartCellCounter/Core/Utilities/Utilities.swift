import Foundation

public enum Logger {
    public static func log(_ message: String) {
        #if DEBUG
        print("[SmartCellCounter] \(message)")
        #endif
    }
}
