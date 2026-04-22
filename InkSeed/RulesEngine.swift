import CoreGraphics
import Foundation

enum MoveValidationResult: Equatable {
    case valid
    case invalid(reason: String)
}

enum RulesEngine {
    static func validateMove(
        stroke: ProcessedStroke,
        gameState: GameState,
        dotCollisionRadius: CGFloat = 14,
        geometryClearance: CGFloat = 10
    ) -> MoveValidationResult {
        guard
            let startDot = gameState.dot(withID: stroke.startDotID),
            let endDot = gameState.dot(withID: stroke.endDotID)
        else {
            return .invalid(reason: "Start ili end nisu dovoljno blizu tačke.")
        }

        if stroke.startDotID == stroke.endDotID {
            if startDot.degree + 2 > gameState.maxDegreePerDot {
                return .invalid(reason: "Tačka nema dovoljno slobodnog stepena za loop.")
            }
        } else if startDot.degree >= gameState.maxDegreePerDot || endDot.degree >= gameState.maxDegreePerDot {
            return .invalid(reason: "Jedna od tačaka je na max degree.")
        }

        if crossesOrTouchesExistingEdges(stroke: stroke, edges: gameState.edges, clearance: geometryClearance) {
            return .invalid(reason: "Linija je preblizu postojećoj geometriji.")
        }

        if passesThroughUnrelatedDots(stroke: stroke, dots: gameState.dots, radius: dotCollisionRadius) {
            return .invalid(reason: "Linija prolazi preblizu druge tačke.")
        }

        return .valid
    }
    
    static func canInsertDotOnPendingStroke(
        tapPoint: CGPoint,
        stroke: ProcessedStroke,
        gameState: GameState,
        tapDistanceTolerance: CGFloat = 24
    ) -> (splitPoint: CGPoint, segmentIndex: Int, t: CGFloat)? {
        guard let closest = Geometry.closestPointOnPolyline(to: tapPoint, polyline: stroke.points) else {
            return nil
        }
        guard closest.distance <= tapDistanceTolerance else { return nil }
        
        // Ne dozvoli novi dot preblizu postojećim tačkama.
        let tooCloseToAnyDot = gameState.dots.contains { Geometry.distance($0.position, closest.point) < 18 }
        guard !tooCloseToAnyDot else { return nil }
        return (closest.point, closest.segmentIndex, closest.t)
    }

    private static func crossesOrTouchesExistingEdges(stroke: ProcessedStroke, edges: [EdgeModel], clearance: CGFloat) -> Bool {

        for edge in edges {
            let sharesEndpoint =
                edge.startDotID == stroke.startDotID ||
                edge.startDotID == stroke.endDotID ||
                edge.endDotID == stroke.startDotID ||
                edge.endDotID == stroke.endDotID
            if !sharesEndpoint && Geometry.polylinesIntersect(stroke.points, edge.points) {
                return true
            }
            
            let distance = Geometry.minDistanceBetweenPolylines(stroke.points, edge.points)
            if sharesEndpoint {
                // Kod zajedničkih tačaka dozvoljavamo malo više prostora za prirodan izlaz poteza.
                if distance < clearance * 0.65 { return true }
            } else if distance < clearance {
                return true
            }
        }
        return false
    }

    private static func passesThroughUnrelatedDots(stroke: ProcessedStroke, dots: [DotModel], radius: CGFloat) -> Bool {
        dots.contains { dot in
            guard dot.id != stroke.startDotID && dot.id != stroke.endDotID else { return false }
            return Geometry.minDistanceFromPoint(dot.position, toPolyline: stroke.points) < radius
        }
    }
}
