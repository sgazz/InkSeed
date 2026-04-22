import CoreGraphics
import Foundation

enum Geometry {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    static func pointAtHalfLength(on points: [CGPoint]) -> CGPoint? {
        guard points.count > 1 else { return nil }
        let total = pathLength(points)
        guard total > 0 else { return points.first }

        let target = total * 0.5
        var walked: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            let segment = distance(a, b)
            if walked + segment >= target {
                let local = (target - walked) / max(segment, 0.001)
                return CGPoint(
                    x: a.x + (b.x - a.x) * local,
                    y: a.y + (b.y - a.y) * local
                )
            }
            walked += segment
        }
        return points.last
    }

    static func minDistanceFromPoint(_ point: CGPoint, toPolyline polyline: [CGPoint]) -> CGFloat {
        guard polyline.count > 1 else { return .greatestFiniteMagnitude }
        return zip(polyline, polyline.dropFirst())
            .map { distanceFromPoint(point, toSegment: $0.0, $0.1) }
            .min() ?? .greatestFiniteMagnitude
    }

    static func minDistanceBetweenPolylines(_ lhs: [CGPoint], _ rhs: [CGPoint]) -> CGFloat {
        guard lhs.count > 1, rhs.count > 1 else { return .greatestFiniteMagnitude }
        var best = CGFloat.greatestFiniteMagnitude
        for ls in zip(lhs, lhs.dropFirst()) {
            for rs in zip(rhs, rhs.dropFirst()) {
                best = min(best, segmentToSegmentDistance(ls.0, ls.1, rs.0, rs.1))
            }
        }
        return best
    }

    static func polylinesIntersect(_ lhs: [CGPoint], _ rhs: [CGPoint], epsilon: CGFloat = 0.5) -> Bool {
        guard lhs.count > 1, rhs.count > 1 else { return false }
        for ls in zip(lhs, lhs.dropFirst()) {
            for rs in zip(rhs, rhs.dropFirst()) {
                if segmentsIntersect(ls.0, ls.1, rs.0, rs.1, epsilon: epsilon) {
                    return true
                }
            }
        }
        return false
    }

    static func closestPointOnPolyline(to point: CGPoint, polyline: [CGPoint]) -> (point: CGPoint, segmentIndex: Int, t: CGFloat, distance: CGFloat)? {
        guard polyline.count > 1 else { return nil }
        var bestPoint = polyline[0]
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestSegment = 0
        var bestT = CGFloat.zero

        for (index, segment) in zip(polyline.indices, zip(polyline, polyline.dropFirst())) {
            let projected = projectPoint(point, ontoSegmentFrom: segment.0, to: segment.1)
            let d = distance(point, projected.point)
            if d < bestDistance {
                bestDistance = d
                bestPoint = projected.point
                bestSegment = index
                bestT = projected.t
            }
        }

        return (bestPoint, bestSegment, bestT, bestDistance)
    }

    static func splitPolyline(_ points: [CGPoint], atSegment segmentIndex: Int, t: CGFloat, splitPoint: CGPoint) -> (left: [CGPoint], right: [CGPoint])? {
        guard points.count > 1 else { return nil }
        guard segmentIndex >= 0, segmentIndex < points.count - 1 else { return nil }
        let clampedT = min(max(t, 0), 1)
        let p0 = points[segmentIndex]
        let p1 = points[segmentIndex + 1]
        let resolvedSplit = clampedT == 0 ? p0 : (clampedT == 1 ? p1 : splitPoint)

        var left = Array(points[0...segmentIndex])
        if distance(left.last ?? resolvedSplit, resolvedSplit) > 0.001 {
            left.append(resolvedSplit)
        }

        var right: [CGPoint] = [resolvedSplit]
        right.append(contentsOf: points[(segmentIndex + 1)...])
        if right.count > 1, distance(right[0], right[1]) < 0.001 {
            right.removeFirst()
            right.insert(resolvedSplit, at: 0)
        }

        guard left.count > 1, right.count > 1 else { return nil }
        return (left, right)
    }

    static func segmentsIntersect(
        _ p1: CGPoint,
        _ p2: CGPoint,
        _ q1: CGPoint,
        _ q2: CGPoint,
        epsilon: CGFloat = 0.5
    ) -> Bool {
        if distance(p1, q1) < epsilon || distance(p1, q2) < epsilon || distance(p2, q1) < epsilon || distance(p2, q2) < epsilon {
            return false
        }

        let o1 = orientation(p1, p2, q1)
        let o2 = orientation(p1, p2, q2)
        let o3 = orientation(q1, q2, p1)
        let o4 = orientation(q1, q2, p2)

        if o1 != o2 && o3 != o4 {
            return true
        }

        if o1 == 0 && onSegment(p1, q1, p2, epsilon: epsilon) { return true }
        if o2 == 0 && onSegment(p1, q2, p2, epsilon: epsilon) { return true }
        if o3 == 0 && onSegment(q1, p1, q2, epsilon: epsilon) { return true }
        if o4 == 0 && onSegment(q1, p2, q2, epsilon: epsilon) { return true }
        return false
    }

    private static func distanceFromPoint(_ point: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let l2 = pow(distance(a, b), 2)
        guard l2 > 0 else { return distance(point, a) }
        let t = max(0, min(1, ((point.x - a.x) * (b.x - a.x) + (point.y - a.y) * (b.y - a.y)) / l2))
        let projection = CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y))
        return distance(point, projection)
    }

    private static func segmentToSegmentDistance(_ a1: CGPoint, _ a2: CGPoint, _ b1: CGPoint, _ b2: CGPoint) -> CGFloat {
        if segmentsIntersect(a1, a2, b1, b2) {
            return 0
        }
        return min(
            distanceFromPoint(a1, toSegment: b1, b2),
            distanceFromPoint(a2, toSegment: b1, b2),
            distanceFromPoint(b1, toSegment: a1, a2),
            distanceFromPoint(b2, toSegment: a1, a2)
        )
    }

    private static func projectPoint(_ point: CGPoint, ontoSegmentFrom a: CGPoint, to b: CGPoint) -> (point: CGPoint, t: CGFloat) {
        let l2 = pow(distance(a, b), 2)
        guard l2 > 0 else { return (a, 0) }
        let t = max(0, min(1, ((point.x - a.x) * (b.x - a.x) + (point.y - a.y) * (b.y - a.y)) / l2))
        return (CGPoint(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)), t)
    }

    private static func orientation(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> Int {
        let value = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y)
        if abs(value) < 0.0001 { return 0 }
        return value > 0 ? 1 : 2
    }

    private static func onSegment(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint, epsilon: CGFloat) -> Bool {
        q.x <= max(p.x, r.x) + epsilon &&
        q.x + epsilon >= min(p.x, r.x) &&
        q.y <= max(p.y, r.y) + epsilon &&
        q.y + epsilon >= min(p.y, r.y)
    }
}
