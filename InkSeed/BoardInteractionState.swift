import CoreGraphics
import Combine
import Foundation

@MainActor
final class BoardInteractionState: ObservableObject {
    @Published var liveStrokePoints: [CGPoint] = []
    @Published var feedbackMessage: String?
    @Published var showFeedback: Bool = false
    @Published var hoverLineTapPoint: CGPoint?

    func beginStroke(points: [CGPoint]) {
        liveStrokePoints = points
    }

    func clearStroke() {
        liveStrokePoints = []
    }

    func showInvalid(_ message: String) {
        feedbackMessage = message
        showFeedback = true
    }

    func hideFeedback() {
        showFeedback = false
    }
}
