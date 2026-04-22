import SwiftUI

struct BoardView: View {
    @ObservedObject var gameState: GameState
    @ObservedObject var interactionState: BoardInteractionState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                boardBackground
                edgeLayer
                pendingLineLayer
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
                        .background(.ultraThinMaterial, in: Capsule())
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
        }
    }

    private var boardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AppTheme.paperBackground, AppTheme.paperBackground.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var edgeLayer: some View {
        Canvas { context, _ in
            for edge in gameState.edges {
                guard edge.points.count > 1 else { continue }
                let path = smoothPath(from: edge.points)
                context.stroke(
                    path,
                    with: .color(AppTheme.graphiteInk.opacity(edge.owner == .one ? 0.9 : 0.75)),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
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
                style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round)
            )
        }
    }
    
    private var pendingLineLayer: some View {
        Canvas { context, _ in
            guard let pending = gameState.pendingMove else { return }
            let path = smoothPath(from: pending.stroke.points)
            context.stroke(
                path,
                with: .color(AppTheme.royalPurple.opacity(0.45)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [8, 5])
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
                let rect = CGRect(x: dot.position.x - 7, y: dot.position.y - 7, width: 14, height: 14)
                let isSelected = selectedDotIDs.contains(dot.id)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(isSelected ? AppTheme.royalPurple.opacity(0.9) : AppTheme.graphiteInk.opacity(0.88))
                )
            }
        }
    }

    private func handleStrokeEnded(_ points: [CGPoint]) {
        interactionState.clearStroke()

        guard let processed = StrokeProcessing.process(rawPoints: points, dots: gameState.dots) else {
            showInvalid("Kreni i završi potez bliže postojećim tačkama.")
            return
        }

        let result = RulesEngine.validateMove(stroke: processed, gameState: gameState)
        switch result {
        case .valid:
            interactionState.hideFeedback()
            gameState.setPendingMove(processed)
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
}
