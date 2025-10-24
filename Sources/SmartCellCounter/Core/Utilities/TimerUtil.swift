import Foundation

public enum TimerUtil {
    @discardableResult
    public static func time<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(start)
        Logger.log("\(label) took \(String(format: "%.2fms", duration * 1000))")
        return result
    }
}
