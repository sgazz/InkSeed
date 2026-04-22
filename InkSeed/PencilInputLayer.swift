import SwiftUI
import UIKit

enum PencilInputMode {
    case placeSetupDot
    case drawStroke
    case tapOnPendingLine
}

struct PencilInputLayer: UIViewRepresentable {
    var mode: PencilInputMode
    var allowFingerInput: Bool = true
    var onTap: (CGPoint) -> Void
    var onStrokeChanged: ([CGPoint]) -> Void
    var onStrokeEnded: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> PencilTouchView {
        let view = PencilTouchView()
        view.backgroundColor = .clear
        view.mode = mode
        view.allowFingerInput = allowFingerInput
        view.onTap = onTap
        view.onStrokeChanged = onStrokeChanged
        view.onStrokeEnded = onStrokeEnded
        return view
    }

    func updateUIView(_ uiView: PencilTouchView, context: Context) {
        uiView.mode = mode
        uiView.allowFingerInput = allowFingerInput
        uiView.onTap = onTap
        uiView.onStrokeChanged = onStrokeChanged
        uiView.onStrokeEnded = onStrokeEnded
    }
}

final class PencilTouchView: UIView {
    var mode: PencilInputMode = .drawStroke
    var allowFingerInput = true
    var onTap: ((CGPoint) -> Void)?
    var onStrokeChanged: (([CGPoint]) -> Void)?
    var onStrokeEnded: (([CGPoint]) -> Void)?

    private var points: [CGPoint] = []
    private var activeTouchID: ObjectIdentifier?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard shouldAccept(touch: touch) else { return }
        activeTouchID = ObjectIdentifier(touch)
        points = [touch.location(in: self)]
        if mode == .drawStroke {
            onStrokeChanged?(points)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch(in: touches) else { return }
        points.append(touch.location(in: self))
        if mode == .drawStroke {
            onStrokeChanged?(points)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackedTouch(in: touches) else { return }
        points.append(touch.location(in: self))

        defer {
            activeTouchID = nil
            points = []
        }

        switch mode {
        case .placeSetupDot, .tapOnPendingLine:
            guard let start = points.first, let end = points.last else { return }
            if Geometry.distance(start, end) < 12 {
                onTap?(end)
            }
        case .drawStroke:
            onStrokeEnded?(points)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchID = nil
        points = []
        onStrokeEnded?([])
    }

    private func trackedTouch(in touches: Set<UITouch>) -> UITouch? {
        guard let activeTouchID else { return nil }
        return touches.first { ObjectIdentifier($0) == activeTouchID }
    }

    private func shouldAccept(touch: UITouch) -> Bool {
        if allowFingerInput {
            return true
        }
        return touch.type == .pencil
    }
}
