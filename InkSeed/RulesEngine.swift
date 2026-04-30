import CoreGraphics
import Foundation

enum MoveValidationResult: Equatable {
    case valid
    case invalid(reason: String)
}

enum RulesEngine {
    private static let sharedEndpointExclusionDistance: CGFloat = 3.0
    private static let pairCurveAmplitudeFactors: [CGFloat] = [0.18, 0.28]
    private static let pairCurveSamples = 7
    private static let loopRadii: [CGFloat] = [22, 30, 38]
    private static let loopSamples = 18

    static func validateMove(
        stroke: ProcessedStroke,
        gameState: GameState,
        profile: GeometryProfile
    ) -> MoveValidationResult {
        guard
            let startDot = gameState.dot(withID: stroke.startDotID),
            let endDot = gameState.dot(withID: stroke.endDotID)
        else {
            return .invalid(reason: NSLocalizedString("move_validation.start_or_end_not_near_dot", comment: "Move validation error when stroke endpoints cannot map to nearby dots"))
        }

        if stroke.startDotID == stroke.endDotID {
            if startDot.degree + 2 > gameState.maxDegreePerDot {
                return .invalid(reason: NSLocalizedString("move_validation.loop_degree_limit_reached", comment: "Move validation error when a loop would exceed node degree"))
            }
        } else if startDot.degree >= gameState.maxDegreePerDot || endDot.degree >= gameState.maxDegreePerDot {
            return .invalid(reason: NSLocalizedString("move_validation.node_max_degree_reached", comment: "Move validation error when one endpoint node already reached max degree"))
        }

        if crossesOrTouchesExistingEdges(stroke: stroke, edges: gameState.edges, profile: profile) {
            return .invalid(reason: NSLocalizedString("move_validation.line_crosses_or_touches_existing", comment: "Move validation error when a stroke intersects existing edges"))
        }

        if passesThroughUnrelatedDots(stroke: stroke, dots: gameState.dots, radius: profile.nodePathCollisionRadius) {
            return .invalid(reason: NSLocalizedString("move_validation.line_too_close_to_other_dot", comment: "Move validation error when a stroke passes too close to unrelated node"))
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

    static func hasAnyLegalMove(
        gameState: GameState,
        profile: GeometryProfile
    ) -> Bool {
        let playableDots = gameState.dots.filter { $0.degree < gameState.maxDegreePerDot }
        guard !playableDots.isEmpty else { return false }

        // Loop kandidati.
        for dot in playableDots where dot.degree + 2 <= gameState.maxDegreePerDot {
            for loop in buildLoopCandidates(for: dot) {
                let stroke = ProcessedStroke(points: loop, startDotID: dot.id, endDotID: dot.id)
                if case .valid = validateMove(stroke: stroke, gameState: gameState, profile: profile),
                   hasLegalInsertionPoint(on: stroke, gameState: gameState) {
                    return true
                }
            }
        }

        // Kandidati između parova čvorova (prava + blage krive).
        guard playableDots.count > 1 else { return false }
        for i in 0..<(playableDots.count - 1) {
            let start = playableDots[i]
            for j in (i + 1)..<playableDots.count {
                let end = playableDots[j]
                for candidate in buildPairCandidates(start: start.position, end: end.position) {
                    let stroke = ProcessedStroke(points: candidate, startDotID: start.id, endDotID: end.id)
                    if case .valid = validateMove(stroke: stroke, gameState: gameState, profile: profile),
                       hasLegalInsertionPoint(on: stroke, gameState: gameState) {
                        return true
                    }
                }
            }
        }

        return false
    }

    private static func hasLegalInsertionPoint(
        on stroke: ProcessedStroke,
        gameState: GameState
    ) -> Bool {
        let candidatePoints = insertionCandidatePoints(on: stroke.points)
        return candidatePoints.contains { point in
            canInsertDotOnPendingStroke(
                tapPoint: point,
                stroke: stroke,
                gameState: gameState,
                tapDistanceTolerance: 3
            ) != nil
        }
    }

    private static func insertionCandidatePoints(on polyline: [CGPoint]) -> [CGPoint] {
        guard polyline.count > 1 else { return [] }

        let fractions: [CGFloat] = [
            0.18, 0.25, 0.33, 0.42, 0.50, 0.58, 0.67, 0.75, 0.82
        ]

        return fractions.compactMap { point(atFraction: $0, on: polyline) }
    }

    private static func point(atFraction fraction: CGFloat, on polyline: [CGPoint]) -> CGPoint? {
        guard polyline.count > 1 else { return nil }

        let clampedFraction = min(max(fraction, 0), 1)
        var totalLength: CGFloat = 0

        for index in 0..<(polyline.count - 1) {
            totalLength += Geometry.distance(polyline[index], polyline[index + 1])
        }

        guard totalLength > 0.001 else { return nil }

        let targetLength = totalLength * clampedFraction
        var walked: CGFloat = 0

        for index in 0..<(polyline.count - 1) {
            let a = polyline[index]
            let b = polyline[index + 1]
            let segmentLength = Geometry.distance(a, b)

            if walked + segmentLength >= targetLength {
                let t = (targetLength - walked) / max(segmentLength, 0.001)
                return CGPoint(
                    x: a.x + (b.x - a.x) * t,
                    y: a.y + (b.y - a.y) * t
                )
            }

            walked += segmentLength
        }

        return polyline.last
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

    private static func buildPairCandidates(start: CGPoint, end: CGPoint) -> [[CGPoint]] {
        var candidates: [[CGPoint]] = [[start, end]]

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return candidates }

        let ux = dx / length
        let uy = dy / length
        let px = -uy
        let py = ux
        let midpoint = CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)

        for factor in pairCurveAmplitudeFactors {
            let offset = min(max(10, length * factor), 55)
            let controlA = CGPoint(x: midpoint.x + px * offset, y: midpoint.y + py * offset)
            let controlB = CGPoint(x: midpoint.x - px * offset, y: midpoint.y - py * offset)
            candidates.append(sampleQuadraticBezier(from: start, control: controlA, to: end, samples: pairCurveSamples))
            candidates.append(sampleQuadraticBezier(from: start, control: controlB, to: end, samples: pairCurveSamples))
        }

        return candidates
    }

    private static func sampleQuadraticBezier(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        samples: Int
    ) -> [CGPoint] {
        let count = max(3, samples)
        return (0..<count).map { index in
            let t = CGFloat(index) / CGFloat(count - 1)
            let mt = 1 - t
            let x = (mt * mt * start.x) + (2 * mt * t * control.x) + (t * t * end.x)
            let y = (mt * mt * start.y) + (2 * mt * t * control.y) + (t * t * end.y)
            return CGPoint(x: x, y: y)
        }
    }

    private static func buildLoopCandidates(for dot: DotModel) -> [[CGPoint]] {
        loopRadii.map { radius in
            sampleLoop(around: dot.position, radius: radius, samples: loopSamples)
        }
    }

    private static func sampleLoop(around center: CGPoint, radius: CGFloat, samples: Int) -> [CGPoint] {
        let count = max(8, samples)
        let start = CGPoint(x: center.x + radius, y: center.y)
        var points: [CGPoint] = [center, start]

        for index in 1..<count {
            let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi
            points.append(
                CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
            )
        }

        points.append(start)
        points.append(center)
        return points
    }
}
