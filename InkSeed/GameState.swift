import CoreGraphics
import Combine
import Foundation

enum AppFlowState {
    case welcome
    case setup
    case play
}

enum TurnPhase {
    case drawLine
    case placeNewDot
}

struct PendingMove {
    let stroke: ProcessedStroke
}

@MainActor
final class GameState: ObservableObject {
    @Published var flowState: AppFlowState = .welcome
    @Published private(set) var dots: [DotModel] = []
    @Published private(set) var edges: [EdgeModel] = []
    @Published var currentPlayer: Player = .one
    @Published var turnPhase: TurnPhase = .drawLine
    @Published var pendingMove: PendingMove?
    @Published var winner: Player?
    @Published var lastInsertedDotID: UUID?
    @Published var geometryProfile: GeometryProfile = .playable

    let maxDegreePerDot: Int = 3
    let minSetupDots: Int = 3
    let maxSetupDots: Int = 6

    func startNewGame() {
        dots = []
        edges = []
        currentPlayer = .one
        turnPhase = .drawLine
        pendingMove = nil
        winner = nil
        lastInsertedDotID = nil
        flowState = .setup
    }

    func restartPlay() {
        startNewGame()
    }

    func enterWelcome() {
        flowState = .welcome
    }

    func canAddSetupDot(at point: CGPoint, minDistance: CGFloat = 28) -> Bool {
        !dots.contains { Geometry.distance($0.position, point) < minDistance }
    }

    func addSetupDot(at point: CGPoint) {
        guard flowState == .setup, dots.count < maxSetupDots else { return }
        guard canAddSetupDot(at: point) else { return }
        dots.append(DotModel(position: point))
    }

    func removeLastSetupDot() {
        guard flowState == .setup, !dots.isEmpty else { return }
        dots.removeLast()
    }

    func finalizeSetupIfPossible() {
        guard dots.count >= minSetupDots else { return }
        winner = nil
        pendingMove = nil
        turnPhase = .drawLine
        flowState = .play
    }

    func setPendingMove(_ stroke: ProcessedStroke) {
        guard flowState == .play else { return }
        pendingMove = PendingMove(stroke: stroke)
        turnPhase = .placeNewDot
    }
    
    func clearPendingMove() {
        pendingMove = nil
        turnPhase = .drawLine
    }

    func placeNewDotForPendingMove(splitPoint: CGPoint, segmentIndex: Int, t: CGFloat) {
        guard flowState == .play else { return }
        guard let pending = pendingMove else { return }
        guard let split = Geometry.splitPolyline(pending.stroke.points, atSegment: segmentIndex, t: t, splitPoint: splitPoint) else { return }
        
        let newDot = DotModel(position: splitPoint, degree: 2)
        dots.append(newDot)
        lastInsertedDotID = newDot.id
        
        if pending.stroke.startDotID == pending.stroke.endDotID {
            incrementDegree(for: pending.stroke.startDotID, amount: 2)
        } else {
            incrementDegree(for: pending.stroke.startDotID, amount: 1)
            incrementDegree(for: pending.stroke.endDotID, amount: 1)
        }
        
        edges.append(
            EdgeModel(
                startDotID: pending.stroke.startDotID,
                endDotID: newDot.id,
                points: split.left,
                owner: currentPlayer
            )
        )
        edges.append(
            EdgeModel(
                startDotID: newDot.id,
                endDotID: pending.stroke.endDotID,
                points: split.right,
                owner: currentPlayer
            )
        )
        
        pendingMove = nil
        turnPhase = .drawLine
        if !hasDegreeBasedTurnPotential() {
            winner = currentPlayer
            return
        }
        currentPlayer.advance()
    }

    func dot(withID id: UUID) -> DotModel? {
        dots.first { $0.id == id }
    }

    private func incrementDegree(for id: UUID, amount: Int) {
        guard let index = dots.firstIndex(where: { $0.id == id }) else { return }
        dots[index].degree += amount
    }
    
    private func hasAnyLegalTurn() -> Bool {
        RulesEngine.hasAnyLegalMove(gameState: self, profile: geometryProfile)
    }

    private func hasDegreeBasedTurnPotential() -> Bool {
        let playableDots = dots.filter { $0.degree < maxDegreePerDot }
        if playableDots.count >= 2 { return true }
        if playableDots.contains(where: { $0.degree + 2 <= maxDegreePerDot }) { return true }
        return false
    }

#if DEBUG
    func debugSetBoardState(
        dots: [DotModel],
        edges: [EdgeModel],
        currentPlayer: Player = .one,
        profile: GeometryProfile? = nil
    ) {
        self.dots = dots
        self.edges = edges
        self.currentPlayer = currentPlayer
        self.geometryProfile = profile ?? .playable
        self.flowState = .play
        self.turnPhase = .drawLine
        self.pendingMove = nil
        self.winner = nil
    }
#endif
}
