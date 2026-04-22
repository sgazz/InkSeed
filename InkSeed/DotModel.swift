import CoreGraphics
import Foundation

struct DotModel: Identifiable, Equatable {
    let id: UUID
    var position: CGPoint
    var degree: Int

    init(id: UUID = UUID(), position: CGPoint, degree: Int = 0) {
        self.id = id
        self.position = position
        self.degree = degree
    }
}
