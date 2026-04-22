import CoreGraphics
import Foundation

struct GeometryProfile {
    let pathClearanceTolerance: CGFloat
    let nodePathCollisionRadius: CGFloat
    let endpointSnapRadius: CGFloat
    let intersectionEpsilon: CGFloat
    let segmentsIntersectDefaultEpsilon: CGFloat
    let sharedEndpointClearance: CGFloat

    static let playable = GeometryProfile(
        pathClearanceTolerance: 0.55,
        nodePathCollisionRadius: 7.0,
        endpointSnapRadius: 30.0,
        intersectionEpsilon: 0.50,
        segmentsIntersectDefaultEpsilon: 0.30,
        sharedEndpointClearance: 0.22
    )

    static let balanced = GeometryProfile(
        pathClearanceTolerance: 0.9,
        nodePathCollisionRadius: 8.0,
        endpointSnapRadius: 29.0,
        intersectionEpsilon: 0.65,
        segmentsIntersectDefaultEpsilon: 0.40,
        sharedEndpointClearance: 0.28
    )
}
