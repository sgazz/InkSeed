import CoreGraphics
import Foundation

struct EdgeModel: Identifiable, Equatable {
    let id: UUID
    let startDotID: UUID
    let endDotID: UUID
    let points: [CGPoint]
    let owner: Player
    let inkPhase: CGFloat

    init(
        id: UUID = UUID(),
        startDotID: UUID,
        endDotID: UUID,
        points: [CGPoint],
        owner: Player,
        inkPhase: CGFloat = .random(in: 0...(2 * .pi))
    ) {
        self.id = id
        self.startDotID = startDotID
        self.endDotID = endDotID
        self.points = points
        self.owner = owner
        self.inkPhase = inkPhase
    }
}
