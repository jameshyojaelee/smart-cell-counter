import SwiftUI

public enum DS {
    public enum Spacing {
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 28
    }

    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
    }

    public enum Shadow {
        public static let card = Color.black.opacity(0.25)
    }

    public enum Typo {
        public static let title = Font.system(.title2, design: .rounded).weight(.bold)
        public static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
        public static let body = Font.system(.body, design: .rounded)
        public static let caption = Font.system(.caption, design: .rounded)
    }
}
