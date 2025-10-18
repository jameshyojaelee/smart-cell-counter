import UIKit

public enum Haptics {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare(); gen.impactOccurred()
    }

    public static func success() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare(); gen.notificationOccurred(.success)
    }

    public static func warning() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare(); gen.notificationOccurred(.warning)
    }

    public static func error() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare(); gen.notificationOccurred(.error)
    }
}

