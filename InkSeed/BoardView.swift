import SwiftUI

struct BoardView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var interactionState: BoardInteractionState
    @State private var settlingStrokePoints: [CGPoint] = []
    @State private var pulseDotID: UUID?
    @State private var pulseProgress: CGFloat = 0
    
    private let nodeOuterDiameter: CGFloat = 12
    private let nodeStrokeWidth: CGFloat = 1.5
    private let nodeHitDiameter: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                boardBackground
                edgeLayer
                pendingLineLayer
                settlingStrokeLayer
                activeStrokeLayer
                dotLayer

                PencilInputLayer(
                    mode: inputMode,
                    allowFingerInput: true,
                    onTap: { point in
                        handleTap(point)
                    },
                    onStrokeChanged: { points in
                        guard gameState.flowState == .play, gameState.turnPhase == .drawLine, gameState.winner == nil else { return }
                        interactionState.beginStroke(points: points)
                    },
                    onStrokeEnded: { points in
                        guard gameState.flowState == .play, gameState.turnPhase == .drawLine, gameState.winner == nil else { return }
                        handleStrokeEnded(points)
                    }
                )

                if interactionState.showFeedback, let message = interactionState.feedbackMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.paperBackground.opacity(0.92), in: Capsule())
                        .overlay(
                            Capsule().stroke(AppTheme.graphiteInk.opacity(0.12), lineWidth: 0.8)
                        )
                        .foregroundStyle(AppTheme.graphiteInk.opacity(0.85))
                        .transition(.opacity.combined(with: .scale))
                        .padding(.top, proxy.safeAreaInsets.top + 18)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.graphiteInk.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: interactionState.showFeedback)
            .onChange(of: gameState.lastInsertedDotID) { _, newValue in
                guard let newValue else { return }
                pulseDotID = newValue
                pulseProgress = 0
                withAnimation(.easeOut(duration: 0.18)) {
                    pulseProgress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    if pulseDotID == newValue {
                        pulseDotID = nil
                        pulseProgress = 0
                    }
                }
            }
        }
    }

    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AppTheme.paperBackground, AppTheme.paperSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        .white.opacity(0.12),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 560
                )
            )
            .overlay(paperGrainOverlay)
    }

    private var paperGrainOverlay: some View {
        Canvas { context, size in
            let count = Int((size.width * size.height) / 5500) // vrlo suptilno, ~2-3% vizuelnog utiska
            for index in 0..<max(40, count) {
                let seed = CGFloat(index + 1)
                let x = pseudoRandom(seed * 17.13) * size.width
                let y = pseudoRandom(seed * 31.77) * size.height
                let dot = CGRect(x: x, y: y, width: 0.9, height: 0.9)
                context.fill(
                    Path(ellipseIn: dot),
                    with: .color(AppTheme.graphiteInk.opacity(0.028))
                )
            }

            let fiberCount = Int((size.width + size.height) / 28)
            for index in 0..<max(18, fiberCount) {
                let seed = CGFloat(index + 1)
                let x = pseudoRandom(seed * 9.12) * size.width
                let y = pseudoRandom(seed * 14.44) * size.height
                let length = 4 + pseudoRandom(seed * 21.9) * 6
                let angle = (pseudoRandom(seed * 3.73) - 0.5) * 0.7
                let dx = cos(angle) * length
                let dy = sin(angle) * length

                var fiber = Path()
                fiber.move(to: CGPoint(x: x, y: y))
                fiber.addLine(to: CGPoint(x: x + dx, y: y + dy))
                context.stroke(
                    fiber,
                    with: .color(.white.opacity(0.03)),
                    style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                )
            }
        }
        .blendMode(.overlay)
        .opacity(0.7)
    }

    private var edgeLayer: some View {
        Canvas { context, _ in
            for edge in gameState.edges {
                guard edge.points.count > 1 else { continue }
                drawInkStroke(
                    in: &context,
                    points: edge.points,
                    undertone: edge.owner == .one ? AppTheme.playerOneUndertone : AppTheme.playerTwoUndertone,
                    baseWidth: 3.5,
                    phase: edge.inkPhase
                )
            }
        }
    }

    private var activeStrokeLayer: some View {
        Canvas { context, _ in
            guard interactionState.liveStrokePoints.count > 1 else { return }
            let path = smoothPath(from: interactionState.liveStrokePoints)
            context.stroke(
                path,
                with: .color(AppTheme.graphiteInk.opacity(0.5)),
                style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private var settlingStrokeLayer: some View {
        Canvas { context, _ in
            guard settlingStrokePoints.count > 1 else { return }
            drawInkStroke(
                in: &context,
                points: settlingStrokePoints,
                undertone: gameState.currentPlayer == .one ? AppTheme.playerOneUndertone : AppTheme.playerTwoUndertone,
                baseWidth: 3.45,
                phase: 0
            )
        }
    }
    
    private var pendingLineLayer: some View {
        Canvas { context, _ in
            guard let pending = gameState.pendingMove else { return }
            let path = smoothPath(from: pending.stroke.points)
            context.stroke(
                path,
                with: .color(AppTheme.royalPurple.opacity(0.25)),
                style: StrokeStyle(lineWidth: 4.4, lineCap: .round, lineJoin: .round, dash: [7, 6])
            )
        }
    }

    private var dotLayer: some View {
        Canvas { context, _ in
            let selectedDotIDs: Set<UUID> = {
                guard let pending = gameState.pendingMove else { return [] }
                return [pending.stroke.startDotID, pending.stroke.endDotID]
            }()

            for dot in gameState.dots {
                let center = dot.position
                let outerRadius = nodeOuterDiameter * 0.5
                let outerRect = CGRect(
                    x: center.x - outerRadius,
                    y: center.y - outerRadius,
                    width: outerRadius * 2,
                    height: outerRadius * 2
                )
                let isSelected = selectedDotIDs.contains(dot.id)
                let isAtFullDegree = dot.degree >= gameState.maxDegreePerDot

                // Minimal depth for a refined board-piece read.
                context.fill(
                    Path(ellipseIn: outerRect.offsetBy(dx: 0, dy: 0.55)),
                    with: .color(AppTheme.graphiteInk.opacity(0.07))
                )

                // Selected node gets a subtle royal purple outer glow ring.
                if isSelected {
                    let glowRect = outerRect.insetBy(dx: -2.1, dy: -2.1)
                    context.stroke(
                        Path(ellipseIn: glowRect),
                        with: .color(AppTheme.royalPurple.opacity(0.42)),
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
                    )
                }

                // Hollow circular node ring.
                context.stroke(
                    Path(ellipseIn: outerRect),
                    with: .color(AppTheme.graphiteInk.opacity(isAtFullDegree ? 0.86 : 0.72)),
                    style: StrokeStyle(lineWidth: nodeStrokeWidth, lineCap: .round, lineJoin: .round)
                )

                // Tiny premium highlight (top-left).
                let highlightRect = CGRect(
                    x: center.x - outerRadius + 2.2,
                    y: center.y - outerRadius + 1.8,
                    width: 1.6,
                    height: 1.6
                )
                context.fill(
                    Path(ellipseIn: highlightRect),
                    with: .color(.white.opacity(0.2))
                )
                
                if pulseDotID == dot.id {
                    let radius = nodeOuterDiameter + ((nodeHitDiameter - nodeOuterDiameter) * 0.48 * pulseProgress)
                    let pulseRect = CGRect(
                        x: center.x - radius * 0.5,
                        y: center.y - radius * 0.5,
                        width: radius,
                        height: radius
                    )
                    // Soft spawn pulse.
                    context.stroke(
                        Path(ellipseIn: pulseRect),
                        with: .color(AppTheme.royalPurple.opacity(0.24 * (1 - pulseProgress))),
                        style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
    }

    private func handleStrokeEnded(_ points: [CGPoint]) {
        interactionState.clearStroke()

        guard let processed = StrokeProcessing.process(
            rawPoints: points,
            dots: gameState.dots,
            profile: gameState.geometryProfile
        ) else {
            showInvalid("Kreni i završi potez bliže postojećim tačkama.")
            return
        }

        let result = RulesEngine.validateMove(
            stroke: processed,
            gameState: gameState,
            profile: gameState.geometryProfile
        )
        switch result {
        case .valid:
            interactionState.hideFeedback()
            let settled = settleStroke(points: processed.points)
            settlingStrokePoints = processed.points
            withAnimation(.easeOut(duration: 0.12)) {
                settlingStrokePoints = settled
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                gameState.setPendingMove(
                    ProcessedStroke(
                        points: settled,
                        startDotID: processed.startDotID,
                        endDotID: processed.endDotID
                    )
                )
                withAnimation(.easeOut(duration: 0.1)) {
                    settlingStrokePoints = []
                }
            }
        case .invalid(let reason):
            showInvalid(reason)
        }
    }
    
    private func handleTap(_ point: CGPoint) {
        if gameState.flowState == .setup {
            gameState.addSetupDot(at: point)
            return
        }
        guard gameState.flowState == .play else { return }
        guard gameState.winner == nil else { return }
        guard gameState.turnPhase == .placeNewDot, let pending = gameState.pendingMove else { return }
        
        guard let insertion = RulesEngine.canInsertDotOnPendingStroke(
            tapPoint: point,
            stroke: pending.stroke,
            gameState: gameState
        ) else {
            showInvalid("Tapni bliže liniji, ali ne preblizu postojećoj tački.")
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            gameState.placeNewDotForPendingMove(
                splitPoint: insertion.splitPoint,
                segmentIndex: insertion.segmentIndex,
                t: insertion.t
            )
        }
    }

    private func showInvalid(_ message: String) {
        interactionState.showInvalid(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            interactionState.hideFeedback()
        }
    }
    
    private var inputMode: PencilInputMode {
        switch gameState.flowState {
        case .setup:
            return .placeSetupDot
        case .play:
            return gameState.turnPhase == .drawLine ? .drawStroke : .tapOnPendingLine
        case .welcome:
            return .tapOnPendingLine
        }
    }
    
    private func settleStroke(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 3 else { return points }
        var adjusted = points
        for idx in 1..<(points.count - 1) {
            let previous = points[idx - 1]
            let current = points[idx]
            let next = points[idx + 1]
            adjusted[idx] = CGPoint(
                x: current.x * 0.62 + ((previous.x + next.x) * 0.19),
                y: current.y * 0.62 + ((previous.y + next.y) * 0.19)
            )
        }
        return adjusted
    }

    private func smoothPath(from points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 2 else {
            path.addLines(points)
            return path
        }

        for index in 1..<points.count {
            let current = points[index]
            let previous = points[index - 1]
            let midPoint = CGPoint(
                x: (current.x + previous.x) * 0.5,
                y: (current.y + previous.y) * 0.5
            )
            path.addQuadCurve(to: midPoint, control: previous)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }
    
    private func drawInkStroke(
        in context: inout GraphicsContext,
        points: [CGPoint],
        undertone: Color,
        baseWidth: CGFloat,
        phase: CGFloat
    ) {
        let path = smoothPath(from: points)
        context.stroke(
            path,
            with: .color(undertone.opacity(0.24)),
            style: StrokeStyle(lineWidth: baseWidth + 0.95, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(AppTheme.graphiteInk.opacity(0.9)),
            style: StrokeStyle(lineWidth: baseWidth, lineCap: .round, lineJoin: .round)
        )

        for (index, segment) in zip(points.indices, zip(points, points.dropFirst())) {
            var segmentPath = Path()
            segmentPath.move(to: segment.0)
            segmentPath.addLine(to: segment.1)
            let modulation = sin(CGFloat(index) * 0.63 + phase) * 0.4
            let width = max(baseWidth - 0.4, min(baseWidth + 0.4, baseWidth + modulation))
            context.stroke(
                segmentPath,
                with: .color(AppTheme.graphiteInk.opacity(0.18)),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func pseudoRandom(_ value: CGFloat) -> CGFloat {
        let raw = sin(value * 12.9898) * 43758.5453
        return raw - floor(raw)
    }
}
