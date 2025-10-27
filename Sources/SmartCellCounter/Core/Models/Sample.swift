import CoreGraphics
import Foundation

public struct Sample: Identifiable, Equatable {
    public let id: String
    public let date: Date
    public let project: String
    public let operatorName: String
    public let liveCount: Int
    public let deadCount: Int
    public let squaresUsed: Int
    public let dilutionFactor: Double
    public let concentrationPerML: Double
    public let thumbnailPath: String?
    public let thumbnailSize: CGSize?
    public let pdfPath: String?
    public let csvPath: String?

    public init(
        id: String,
        date: Date,
        project: String,
        operatorName: String,
        liveCount: Int,
        deadCount: Int,
        squaresUsed: Int,
        dilutionFactor: Double,
        concentrationPerML: Double,
        thumbnailPath: String?,
        thumbnailSize: CGSize?,
        pdfPath: String?,
        csvPath: String?
    ) {
        self.id = id
        self.date = date
        self.project = project
        self.operatorName = operatorName
        self.liveCount = liveCount
        self.deadCount = deadCount
        self.squaresUsed = squaresUsed
        self.dilutionFactor = dilutionFactor
        self.concentrationPerML = concentrationPerML
        self.thumbnailPath = thumbnailPath
        self.thumbnailSize = thumbnailSize
        self.pdfPath = pdfPath
        self.csvPath = csvPath
    }
}
