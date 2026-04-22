import CoreGraphics
import Foundation

enum MoveValidationResult: Equatable {
    case valid
    case invalid(reason: String)
}

enum RulesEngine {
    private static let sharedEndpointExclusionDistance: CGFloat = 3.0

    static func validateMove(
        stroke: ProcessedStroke,
        gameState: GameState,
        profile: GeometryProfile
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

        if crossesOrTouchesExistingEdges(stroke: stroke, edges: gameState.edges, profile: profile) {
            return .invalid(reason: "Linija seče ili dodiruje postojeću liniju.")
        }

        if passesThroughUnrelatedDots(stroke: stroke, dots: gameState.dots, radius: profile.nodePathCollisionRadius) {
            return .invalid(reason: "Linija prolazi preblizu druge tačke.")
        }

        return .valid
    }
    
    static func canInsertDotOnPendingStroke(
        tapPoint: CGPoint,
        stroke: ProcessedStroke,
        gameState: GameState,
        tapDistanceTolerance: CGFloat = 28
    ) -> (splitPoint: CGPoint, segmentIndex: Int, t: CGFloat)? {
        guard let closest = Geometry.closestPointOnPolyline(to: tapPoint, polyline: stroke.points) else {
            return nil
        }
        guard closest.distance <= tapDistanceTolerance else { return nil }
        
        // Ne dozvoli novi dot preblizu postojećim tačkama.
        // Ostavlja približno 28pt "nevidljivu" zonu oko noda.
        let tooCloseToAnyDot = gameState.dots.contains { Geometry.distance($0.position, closest.point) < 14 }
        guard !tooCloseToAnyDot else { return nil }
        return (closest.point, closest.segmentIndex, closest.t)
    }

    private static func crossesOrTouchesExistingEdges(
        stroke: ProcessedStroke,
        edges: [EdgeModel],
        profile: GeometryProfile
    ) -> Bool {

        for edge in edges {
            let sharesEndpoint =
                edge.startDotID == stroke.startDotID ||
                edge.startDotID == stroke.endDotID ||
                edge.endDotID == stroke.startDotID ||
                edge.endDotID == stroke.endDotID
            if sharesEndpoint {
                // Micro-fix: ne merimo "globalnu" udaljenost preko samog zajedničkog čvora.
                // Prvo odsečemo mali izlazni prozor oko shared endpoint-a, pa tek onda merimo touch/cross.
                let sharedPoints = sharedEndpointPoints(stroke: stroke, edge: edge)
                let trimmedStroke = trimForSharedEndpointZone(
                    points: stroke.points,
                    sharedPoints: sharedPoints,
                    exclusionDistance: sharedEndpointExclusionDistance
                )
                let trimmedEdge = trimForSharedEndpointZone(
                    points: edge.points,
                    sharedPoints: sharedPoints,
                    exclusionDistance: sharedEndpointExclusionDistance
                )

                guard trimmedStroke.count > 1, trimmedEdge.count > 1 else {
                    continue
                }

                if Geometry.polylinesIntersect(trimmedStroke, trimmedEdge, epsilon: profile.intersectionEpsilon) {
                    return true
                }

                let distance = Geometry.minDistanceBetweenPolylines(
                    trimmedStroke,
                    trimmedEdge,
                    segmentsIntersectEpsilon: profile.segmentsIntersectDefaultEpsilon
                )
                if distance < profile.sharedEndpointClearance { return true }
            } else {
                if Geometry.polylinesIntersect(stroke.points, edge.points, epsilon: profile.intersectionEpsilon) {
                    return true
                }

                let distance = Geometry.minDistanceBetweenPolylines(
                    stroke.points,
                    edge.points,
                    segmentsIntersectEpsilon: profile.segmentsIntersectDefaultEpsilon
                )
                if distance < profile.pathClearanceTolerance { return true }
            }
        }
        return false
    }

    private static func sharedEndpointPoints(stroke: ProcessedStroke, edge: EdgeModel) -> [CGPoint] {
        var points: [CGPoint] = []

        if stroke.startDotID == edge.startDotID || stroke.startDotID == edge.endDotID {
            if let start = stroke.points.first {
                points.append(start)
            }
        }
        if stroke.endDotID == edge.startDotID || stroke.endDotID == edge.endDotID {
            if let end = stroke.points.last {
                points.append(end)
            }
        }

        return points
    }

    private static func trimForSharedEndpointZone(
        points: [CGPoint],
        sharedPoints: [CGPoint],
        exclusionDistance: CGFloat
    ) -> [CGPoint] {
        var trimmed = points
        for shared in sharedPoints {
            if let first = trimmed.first, Geometry.distance(first, shared) <= 1.2 {
                trimmed = trimFromStart(trimmed, distance: exclusionDistance)
            }
            if let last = trimmed.last, Geometry.distance(last, shared) <= 1.2 {
                trimmed = trimFromEnd(trimmed, distance: exclusionDistance)
            }
        }
        return trimmed
    }

    private static func trimFromStart(_ points: [CGPoint], distance target: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        guard target > 0 else { return points }

        var walked: CGFloat = 0
        for index in 0..<(points.count - 1) {
            let a = points[index]
            let b = points[index + 1]
            let segment = Geometry.distance(a, b)
            if walked + segment >= target {
                let t = (target - walked) / max(segment, 0.001)
                let newStart = CGPoint(
                    x: a.x + (b.x - a.x) * t,
                    y: a.y + (b.y - a.y) * t
                )
                var result = [newStart]
                result.append(contentsOf: points[(index + 1)...])
                return result
            }
            walked += segment
        }
        return Array(points.suffix(1))
    }

    private static func trimFromEnd(_ points: [CGPoint], distance target: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        guard target > 0 else { return points }

        let reversed = Array(points.reversed())
        let trimmedReversed = trimFromStart(reversed, distance: target)
        return Array(trimmedReversed.reversed())
    }

    private static func passesThroughUnrelatedDots(stroke: ProcessedStroke, dots: [DotModel], radius: CGFloat) -> Bool {
        dots.contains { dot in
            guard dot.id != stroke.startDotID && dot.id != stroke.endDotID else { return false }
            return Geometry.minDistanceFromPoint(dot.position, toPolyline: stroke.points) < radius
        }
    }
}
