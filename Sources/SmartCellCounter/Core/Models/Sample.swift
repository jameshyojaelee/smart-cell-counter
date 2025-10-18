import Foundation
import UIKit

public struct Sample: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let thumbnail: UIImage?
    public let project: String
    public let operatorName: String
    public let liveCount: Int
    public let deadCount: Int
    public let squaresUsed: Int
    public let dilutionFactor: Double
    public let concentrationPerML: Double

    public init(id: UUID = UUID(), date: Date = Date(), thumbnail: UIImage?, project: String = "", operatorName: String = "", liveCount: Int, deadCount: Int, squaresUsed: Int, dilutionFactor: Double, concentrationPerML: Double) {
        self.id = id
        self.date = date
        self.thumbnail = thumbnail
        self.project = project
        self.operatorName = operatorName
        self.liveCount = liveCount
        self.deadCount = deadCount
        self.squaresUsed = squaresUsed
        self.dilutionFactor = dilutionFactor
        self.concentrationPerML = concentrationPerML
    }
}

