import XCTest
@testable import InkSeed

@MainActor
final class RulesEngineSharedEndpointRegressionTests: XCTestCase {
    func testLegalSecondMoveFromAlreadyConnectedNode() {
        let a = DotModel(id: UUID(), position: CGPoint(x: 100, y: 100), degree: 1)
        let b = DotModel(id: UUID(), position: CGPoint(x: 220, y: 100), degree: 1)
        let c = DotModel(id: UUID(), position: CGPoint(x: 150, y: 185), degree: 0)

        let existing = EdgeModel(
            startDotID: a.id,
            endDotID: b.id,
            points: [a.position, CGPoint(x: 160, y: 100), b.position],
            owner: .one
        )

        let state = GameState()
        state.debugSetBoardState(dots: [a, b, c], edges: [existing], profile: .playable)

        let stroke = ProcessedStroke(
            points: [a.position, CGPoint(x: 122, y: 118), CGPoint(x: 136, y: 144), c.position],
            startDotID: a.id,
            endDotID: c.id
        )

        XCTAssertEqual(
            RulesEngine.validateMove(stroke: stroke, gameState: state, profile: .playable),
            .valid
        )
    }

    func testLegalSharedEndpointExitUnderSmallAngle() {
        let a = DotModel(id: UUID(), position: CGPoint(x: 120, y: 120), degree: 1)
        let b = DotModel(id: UUID(), position: CGPoint(x: 260, y: 120), degree: 1)
        let c = DotModel(id: UUID(), position: CGPoint(x: 255, y: 170), degree: 0)

        let existing = EdgeModel(
            startDotID: a.id,
            endDotID: b.id,
            points: [a.position, CGPoint(x: 190, y: 120), b.position],
            owner: .one
        )

        let state = GameState()
        state.debugSetBoardState(dots: [a, b, c], edges: [existing], profile: .playable)

        let stroke = ProcessedStroke(
            points: [a.position, CGPoint(x: 134, y: 124), CGPoint(x: 184, y: 142), c.position],
            startDotID: a.id,
            endDotID: c.id
        )

        XCTAssertEqual(
            RulesEngine.validateMove(stroke: stroke, gameState: state, profile: .playable),
            .valid
        )
    }

    func testIllegalOverlapAfterSharedEndpointZone() {
        let a = DotModel(id: UUID(), position: CGPoint(x: 80, y: 100), degree: 1)
        let b = DotModel(id: UUID(), position: CGPoint(x: 240, y: 100), degree: 1)
        let c = DotModel(id: UUID(), position: CGPoint(x: 285, y: 100), degree: 0)

        let existing = EdgeModel(
            startDotID: a.id,
            endDotID: b.id,
            points: [a.position, CGPoint(x: 160, y: 100), b.position],
            owner: .one
        )

        let state = GameState()
        state.debugSetBoardState(dots: [a, b, c], edges: [existing], profile: .playable)

        let overlapStroke = ProcessedStroke(
            points: [a.position, CGPoint(x: 146, y: 100), CGPoint(x: 205, y: 100), c.position],
            startDotID: a.id,
            endDotID: c.id
        )

        switch RulesEngine.validateMove(stroke: overlapStroke, gameState: state, profile: .playable) {
        case .invalid:
            XCTAssertTrue(true)
        case .valid:
            XCTFail("Expected overlap beyond shared-endpoint zone to be invalid.")
        }
    }

    func testIllegalCrossingAfterLeavingSharedEndpointZone() {
        let a = DotModel(id: UUID(), position: CGPoint(x: 100, y: 100), degree: 1)
        let b = DotModel(id: UUID(), position: CGPoint(x: 250, y: 100), degree: 1)
        let c = DotModel(id: UUID(), position: CGPoint(x: 210, y: 60), degree: 1)
        let d = DotModel(id: UUID(), position: CGPoint(x: 210, y: 180), degree: 1)
        let e = DotModel(id: UUID(), position: CGPoint(x: 300, y: 165), degree: 0)

        let horizontal = EdgeModel(
            startDotID: a.id,
            endDotID: b.id,
            points: [a.position, CGPoint(x: 175, y: 100), b.position],
            owner: .one
        )
        let vertical = EdgeModel(
            startDotID: c.id,
            endDotID: d.id,
            points: [c.position, CGPoint(x: 210, y: 120), d.position],
            owner: .two
        )

        let state = GameState()
        state.debugSetBoardState(dots: [a, b, c, d, e], edges: [horizontal, vertical], profile: .playable)

        let crossingStroke = ProcessedStroke(
            points: [a.position, CGPoint(x: 162, y: 122), CGPoint(x: 218, y: 132), e.position],
            startDotID: a.id,
            endDotID: e.id
        )

        switch RulesEngine.validateMove(stroke: crossingStroke, gameState: state, profile: .playable) {
        case .invalid:
            XCTAssertTrue(true)
        case .valid:
            XCTFail("Expected crossing after shared-endpoint exit zone to be invalid.")
        }
    }
}
