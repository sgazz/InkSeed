import CoreGraphics
import Foundation

struct ProcessedStroke {
    let points: [CGPoint]
    let startDotID: UUID
    let endDotID: UUID
}

enum StrokeProcessing {
    static func process(
        rawPoints: [CGPoint],
        dots: [DotModel],
        profile: GeometryProfile
    ) -> ProcessedStroke? {
        guard rawPoints.count > 3 else { return nil }

        let smoothed = smooth(rawPoints, window: 2)
        let simplified = adaptiveSimplify(smoothed)
        guard Geometry.pathLength(simplified) > 35 else { return nil }

        guard
            let first = simplified.first,
            let last = simplified.last,
            let startDot = nearestDot(to: first, dots: dots, maxDistance: profile.endpointSnapRadius),
            let endDot = nearestDot(to: last, dots: dots, maxDistance: profile.endpointSnapRadius)
        else {
            return nil
        }

        var adjusted = simplified
        adjusted[0] = startDot.position
        adjusted[adjusted.count - 1] = endDot.position

        return ProcessedStroke(points: adjusted, startDotID: startDot.id, endDotID: endDot.id)
    }

    private static func nearestDot(to point: CGPoint, dots: [DotModel], maxDistance: CGFloat) -> DotModel? {
        dots
            .map { ($0, Geometry.distance(point, $0.position)) }
            .filter { $0.1 <= maxDistance }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func smooth(_ points: [CGPoint], window: Int) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let radius = max(1, window)
        return points.indices.map { idx in
            let lower = max(0, idx - radius)
            let upper = min(points.count - 1, idx + radius)
            let slice = points[lower...upper]
            let avgX = slice.reduce(CGFloat.zero) { $0 + $1.x } / CGFloat(slice.count)
            let avgY = slice.reduce(CGFloat.zero) { $0 + $1.y } / CGFloat(slice.count)
            return CGPoint(x: avgX, y: avgY)
        }
    }

    private static func adaptiveSimplify(_ points: [CGPoint]) -> [CGPoint] {
        let aggressivelySimplified = douglasPeucker(points, tolerance: 0.9)
        let minKept = max(8, points.count / 4)

        // Feel-first: ako je potez previše "ispeglan", zadržavamo više prirodne putanje.
        if aggressivelySimplified.count < minKept {
            return downsample(points, maxCount: 90)
        }
        return aggressivelySimplified
    }

    private static func downsample(_ points: [CGPoint], maxCount: Int) -> [CGPoint] {
        guard points.count > maxCount else { return points }
        let step = Double(points.count - 1) / Double(maxCount - 1)
        var sampled: [CGPoint] = []
        sampled.reserveCapacity(maxCount)
        for i in 0..<maxCount {
            let idx = Int((Double(i) * step).rounded())
            sampled.append(points[min(idx, points.count - 1)])
        }
        return sampled
    }

    private static func douglasPeucker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var maxDistance: CGFloat = 0
        var index = 0
        let end = points.count - 1

        for i in 1..<end {
            let d = perpendicularDistance(point: points[i], lineStart: points[0], lineEnd: points[end])
            if d > maxDistance {
                maxDistance = d
                index = i
            }
        }

        if maxDistance > tolerance {
            let left = Array(points[0...index])
            let right = Array(points[index...end])
            return Array(douglasPeucker(left, tolerance: tolerance).dropLast()) + douglasPeucker(right, tolerance: tolerance)
        } else {
            return [points[0], points[end]]
        }
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let numerator = abs((lineEnd.y - lineStart.y) * point.x - (lineEnd.x - lineStart.x) * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        let denominator = hypot(lineEnd.y - lineStart.y, lineEnd.x - lineStart.x)
        guard denominator > 0 else { return Geometry.distance(point, lineStart) }
        return numerator / denominator
    }
}
