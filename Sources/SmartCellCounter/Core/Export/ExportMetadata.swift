import Foundation

public struct ExportMetadata: Equatable {
    public let labName: String
    public let stain: String
    public let dilution: Double

    public init(labName: String, stain: String, dilution: Double) {
        self.labName = labName
        self.stain = stain
        self.dilution = dilution
    }

    public var formattedDilution: String {
        L10n.Results.dilutionValue(dilution)
    }

    public var isEmpty: Bool {
        labName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            stain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            dilution == 0
    }
}
